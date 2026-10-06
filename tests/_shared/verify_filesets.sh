#!/usr/bin/env bash
# verify_filesets.sh <output_folder> <manifest.test.json>
# Reads expected_outputs (array of glob patterns, relative to <output_folder>)
# and confirms each glob matches at least one file. Exits 0 on full match,
# 1 on the first missing pattern. Patterns are bash globs; ** is expanded.

set -euo pipefail
shopt -s globstar nullglob

out_dir="$1"
manifest="$2"

if [[ ! -d "$out_dir" ]]; then
    echo "verify_filesets: output dir does not exist: $out_dir" >&2
    exit 1
fi

expected=$(jq -r '.expected_outputs[]?' "$manifest")
if [[ -z "$expected" ]]; then
    echo "verify_filesets: no expected_outputs declared, skipping" >&2
    exit 0
fi

cd "$out_dir"
missing=0
while IFS= read -r pat; do
    [[ -z "$pat" ]] && continue
    matches=( $pat )
    if (( ${#matches[@]} == 0 )); then
        echo "MISSING: pattern '$pat' matched no files under $out_dir" >&2
        missing=$((missing+1))
    else
        echo "ok: '$pat' matched ${#matches[@]} file(s): ${matches[0]}..."
    fi
done <<< "$expected"

if (( missing > 0 )); then
    echo "verify_filesets: $missing pattern(s) had no matches" >&2
    exit 1
fi
echo "verify_filesets: all patterns matched"
