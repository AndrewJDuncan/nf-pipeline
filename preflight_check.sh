#!/usr/bin/env bash
set -euo pipefail

# -------- config --------
# Expected filename pattern (loose but catches your examples that deviate)
#   DW-63-<digits>__RNA__S_ ... _R1_/_R2_ ... .fastq(.gz)
name_regex='^DW-63-[0-9]+__RNA__S_.*_R[12]_.*\.(fastq|fq)(\.gz)?$'

# -------- helpers --------
first_header() {
  # Print first line of FASTQ (gz or plain)
  # zcat -f is pretty universal; gunzip -c also works if needed.
  zcat -f -- "$1" 2>/dev/null | head -n 1 || true
}

# -------- main --------
fail_umi=()
fail_name=()
checked=0

# Find candidate files (case-insensitive)
# shellcheck disable=SC2016
while IFS= read -r -d '' f; do
  ((checked++))
  base="${f##*/}"

  # filename check
  if ! [[ "$base" =~ $name_regex ]]; then
    fail_name+=("$base")
  fi

  # header / UMI check
  hdr="$(first_header "$f")"
  if [[ -z "$hdr" ]]; then
    fail_umi+=("$base (empty/unreadable)")
    continue
  fi

  # Take token before any space, split on :
  first_token="${hdr%% *}"
  IFS=':' read -r -a fields <<< "$first_token"
  if (( ${#fields[@]} != 8 )); then
    fail_umi+=("$base (found ${#fields[@]} fields, expected 8)")
    continue
  fi

  umi="${fields[7]}"  # 8th field (0-based index 7)
  if [[ ! "$umi" =~ ^[ACGTN]{12}$ ]]; then
    fail_umi+=("$base (bad UMI: '$umi')")
  fi
done < <(find . -maxdepth 1 -type f \
  \( -iname "*.fastq" -o -iname "*.fq" -o -iname "*.fastq.gz" -o -iname "*.fq.gz" \) -print0)

echo "Directory: $(pwd)"
echo "FASTQ files found: $checked"
echo

status=0

if ((${#fail_umi[@]} > 0)); then
  status=1
  echo "❌ UMI/header check FAILED for ${#fail_umi[@]} file(s):"
  printf '  - %s\n' "${fail_umi[@]}"
  echo
else
  echo "✅ UMI/header check passed for all files."
fi

if ((${#fail_name[@]} > 0)); then
  status=1
  echo "❌ Filename pattern check FAILED for ${#fail_name[@]} file(s):"
  echo "   Expected like: DW-63-<digits>__RNA__S_..._R1_/R2_... .fastq[.gz]"
  printf '  - %s\n' "${fail_name[@]}"
  echo
else
  echo "✅ Filename pattern check passed for all files."
fi

if (( status == 0 )); then
  echo "🎉 All clear — filenames and UMIs look good."
else
  echo "⚠️  Issues detected. Review the files listed above."
fi

exit "$status"
