#!/usr/bin/env bash
# Sentieon Secondary Analysis regression test suite driver.
# See README.md for the pass/fail contract.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- args ---------------------------------------------------------------
PATTERN=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -k|--pattern) PATTERN="$2"; shift 2 ;;
        --dry-run)    DRY_RUN=1; shift ;;
        -h|--help)
            sed -n '/^# Sentieon/,/^$/p' "$0" | head -20
            echo ""
            echo "Usage: $0 [-k|--pattern <substring>] [--dry-run] [<substring>]"
            exit 0 ;;
        *) PATTERN="$1"; shift ;;
    esac
done

# --- gautil env (idempotent) -------------------------------------------
: "${GAUTIL:=/opt/ghdata/workspaces/staging_grch38/Documents/reinman/linux_tools-3.1.0-DEV1/gautil/gautil}"
: "${GH_WORKSPACE_URL:=https://internal.goldenhelix.com/w/staging_grch38}"
if [[ -z "${GH_API_KEY:-}" ]]; then
    GH_API_KEY=$(sed -n 's/^internal.goldenhelix.com: *//p' \
        /opt/ghdata/workspaces/staging_grch38/Documents/reinman/api_key)
fi
export GH_WORKSPACE_URL GH_API_KEY

mkdir -p logs

# --- helpers ----------------------------------------------------------
fatal() { echo "FATAL: $*" >&2; exit 2; }
need()  { command -v "$1" >/dev/null 2>&1 || fatal "missing required tool: $1"; }
need jq
[[ -x "$GAUTIL" ]] || fatal "gautil binary not executable: $GAUTIL"

# --- main loop --------------------------------------------------------
PASS=0; FAIL=0; SKIP=0
RESULTS=()

shopt -s nullglob
manifests=(*.test.json)
[[ ${#manifests[@]} -gt 0 ]] || fatal "no *.test.json manifests in $(pwd)"

for manifest in $(printf '%s\n' "${manifests[@]}" | sort); do
    name=$(jq -r .name "$manifest")
    if [[ -n "$PATTERN" && "$name" != *"$PATTERN"* ]]; then
        SKIP=$((SKIP+1)); continue
    fi

    workflow=$(jq -r .workflow_path "$manifest")
    echo ""
    echo "================================================================"
    echo "[TEST] $name"
    echo "       workflow: $workflow"

    # Build -p args
    p_args=()
    while IFS=$'\t' read -r k v; do
        [[ -z "$k" ]] && continue
        p_args+=(-p "$k=$v")
    done < <(jq -r '.params // {} | to_entries[] | "\(.key)\t\(.value)"' "$manifest")

    # Build -s args (per-stage settings, e.g. runStep overrides beyond --include/--skip)
    s_args=()
    while IFS=$'\t' read -r k v; do
        [[ -z "$k" ]] && continue
        s_args+=(-s "$k=$v")
    done < <(jq -r '.settings // {} | to_entries[] | "\(.key)\t\(.value)"' "$manifest")

    # --include / --skip
    extra_args=()
    if jq -e '.include // empty' "$manifest" >/dev/null; then
        inc=$(jq -r '.include | join(",")' "$manifest")
        extra_args+=("--include=$inc")
    fi
    if jq -e '.skip // empty' "$manifest" >/dev/null; then
        skp=$(jq -r '.skip | join(",")' "$manifest")
        extra_args+=("--skip=$skp")
    fi

    cmd=("$GAUTIL" client workflow-run "$workflow" "${p_args[@]}" "${s_args[@]}" "${extra_args[@]}" --wait)

    if (( DRY_RUN )); then
        printf '       DRY-RUN:'; printf ' %q' "${cmd[@]}"; echo
        continue
    fi

    # Wipe the per-test output dir before each run so stale artifacts from a
    # previous attempt don't get re-consumed by downstream stages (e.g. the
    # long-read merge stage globs for *.minimap2.bam, would pick up old output).
    out_dir_clean=$(jq -r '.output_folder // ""' "$manifest")
    if [[ -n "$out_dir_clean" && -d "$out_dir_clean" ]]; then
        echo "       wiping stale output: $out_dir_clean"
        rm -rf "$out_dir_clean"/*
    fi

    log="logs/${name}.log"
    : > "$log"
    if "${cmd[@]}" 2>&1 | tee -a "$log"; then
        run_ok=1
    else
        run_ok=0
    fi

    # Verify output file-set
    out_dir=$(jq -r '.output_folder // ""' "$manifest")
    if (( run_ok )) && [[ -n "$out_dir" ]]; then
        if "$SCRIPT_DIR/_shared/verify_filesets.sh" "$out_dir" "$manifest" >>"$log" 2>&1; then
            fileset_ok=1
        else
            fileset_ok=0
        fi
    elif (( run_ok )); then
        fileset_ok=1   # nothing to verify
    else
        fileset_ok=0
    fi

    # Clinical-variant retention (e2e tests only)
    if (( run_ok && fileset_ok )) && jq -e '.expected_clinical_variants // empty' "$manifest" >/dev/null; then
        if "$SCRIPT_DIR/_shared/verify_clinical_variants.sh" "$out_dir" "$manifest" >>"$log" 2>&1; then
            clinvar_ok=1
        else
            clinvar_ok=0
        fi
    else
        clinvar_ok=1
    fi

    if (( run_ok && fileset_ok && clinvar_ok )); then
        echo "[PASS] $name"
        PASS=$((PASS+1)); RESULTS+=("PASS  $name")
    else
        why=""
        (( run_ok ))      || why+=" run-failed"
        (( fileset_ok ))  || why+=" missing-files"
        (( clinvar_ok ))  || why+=" missing-clinical-variants"
        echo "[FAIL]$why  $name  (see $log)"
        FAIL=$((FAIL+1)); RESULTS+=("FAIL$why  $name")
    fi
done

echo ""
echo "================================================================"
echo "SUMMARY: $PASS passed / $FAIL failed / $SKIP skipped"
printf '  %s\n' "${RESULTS[@]}"
exit $(( FAIL > 0 ? 1 : 0 ))
