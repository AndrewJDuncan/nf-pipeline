#!/usr/bin/env bash
# preflight_check.sh — run from inside your FASTQ directory

set -uo pipefail   # no `-e` so we always print a summary

# Filename check: start DW-63-, has "__RNA__", has _R1_/_R2_, ends with .fastq[.gz]/.fq[.gz]
name_regex='^DW-63-[0-9]+__RNA__.*_R[12]_.*\.(fastq|fq)(\.gz)?$'

fail_umi=""
fail_name=""
checked=0

first_header () {
  # prints the FIRST line of a (gz/plain) FASTQ or nothing on failure
  zcat -f -- "$1" 2>/dev/null | head -n 1
}

for f in *.fastq *.fq *.fastq.gz *.fq.gz; do
  [[ -e "$f" ]] || continue
  checked=$((checked+1))
  base="${f##*/}"

  # --- filename check ---
  if [[ ! "$base" =~ $name_regex ]]; then
    fail_name+=$'\n'"  - $base"
  fi

  # --- header / UMI check ---
  hdr="$(first_header "$f")"
  if [[ -z "$hdr" ]]; then
    fail_umi+=$'\n'"  - $base (empty/unreadable)"
    continue
  fi

  # token before first space; split on ':'
  first_token="${hdr%% *}"

  # count fields
  field_count=$(awk -F: '{print NF}' <<<"$first_token")
  if [[ "$field_count" -lt 8 ]]; then
    fail_umi+=$'\n'"  - $base (found $field_count fields, expected ≥8)"
    continue
  fi

  # grab 8th field
  umi=$(awk -F: '{print $8}' <<<"$first_token")
  if [[ ! "$umi" =~ ^[ACGTN]{12}$ ]]; then
    fail_umi+=$'\n'"  - $base (bad UMI: '$umi')"
  fi
done

echo "Directory: $(pwd)"
echo "FASTQ files found: $checked"
echo

status=0

if [[ -n "$fail_umi" ]]; then
  status=1
  echo "❌ UMI/header check FAILED for:"
  echo "$fail_umi"
  echo
else
  echo "✅ UMI/header check passed for all files."
fi

if [[ -n "$fail_name" ]]; then
  status=1
  echo "❌ Filename pattern check FAILED for:"
  echo "   Expected to loosely match: DW-63-<digits>__RNA__..._R1_/R2_... .fastq[.gz]"
  echo "$fail_name"
  echo
else
  echo "✅ Filename pattern check passed for all files."
fi

if [[ "$status" -eq 0 ]]; then
  echo "🎉 All clear — filenames and UMIs look good."
else
  echo "⚠️  Issues detected. Review the files listed above."
fi

exit "$status"
