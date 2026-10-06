#!/usr/bin/env bash
# verify_clinical_variants.sh <output_folder> <manifest.test.json>
# For end-to-end VarSeq workflows: confirms a checked-in set of clinically
# relevant variants is retained in the final small-variant VCF.
#
# Manifest fields:
#   expected_clinical_variants:
#     vcf_glob: "**/*.vcf.gz"           # glob within out_dir to locate the final VCF
#     variants:                         # each must appear in the VCF
#       - "chr1:12345:A>G"
#       - "chr19:50456789:T>C"
#
# Coordinate format expected: <chrom>:<pos>:<ref>><alt>  (1-based).

set -euo pipefail
shopt -s globstar nullglob

out_dir="$1"
manifest="$2"

vcf_glob=$(jq -r '.expected_clinical_variants.vcf_glob // ""' "$manifest")
variants=$(jq -r '.expected_clinical_variants.variants[]? // ""' "$manifest")

if [[ -z "$vcf_glob" || -z "$variants" ]]; then
    echo "verify_clinical_variants: nothing declared, skipping"; exit 0
fi

cd "$out_dir"
matches=( $vcf_glob )
if (( ${#matches[@]} == 0 )); then
    echo "verify_clinical_variants: vcf_glob '$vcf_glob' matched no files under $out_dir" >&2
    exit 1
fi
# Use the first match (workflows produce 1 final small-variant VCF per sample,
# but this helper expects exactly one; if multiple, only the first is checked)
vcf="${matches[0]}"
echo "verify_clinical_variants: checking $vcf"

missing=0
while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    chrom="${v%%:*}"
    rest="${v#*:}"
    pos="${rest%%:*}"
    alleles="${rest#*:}"
    ref="${alleles%%>*}"
    alt="${alleles#*>}"
    # Tabix lookup if indexed; else zcat-grep fallback
    if [[ -f "${vcf}.tbi" || -f "${vcf}.csi" ]]; then
        line=$(tabix "$vcf" "${chrom}:${pos}-${pos}" 2>/dev/null | awk -v r="$ref" -v a="$alt" '$4==r && $5==a {print; exit}')
    else
        line=$(zcat -- "$vcf" | awk -v c="$chrom" -v p="$pos" -v r="$ref" -v a="$alt" '!/^#/ && $1==c && $2==p && $4==r && $5==a {print; exit}')
    fi
    if [[ -z "$line" ]]; then
        echo "MISSING clinical variant: $v" >&2
        missing=$((missing+1))
    else
        echo "ok: $v retained"
    fi
done <<< "$variants"

if (( missing > 0 )); then
    echo "verify_clinical_variants: $missing variant(s) missing" >&2
    exit 1
fi
echo "verify_clinical_variants: all clinical variants retained"
