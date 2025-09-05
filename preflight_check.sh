#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

echo "Directory containing FASTQ files:"
read -r DIR
if [[ -z "${DIR}" || ! -d "${DIR}" ]]; then
  echo "Error: '${DIR}' is not a directory." >&2
  exit 2
fi

# Loosely enforce your naming:
#  - Starts with DW-63-
#  - then digits
#  - then __RNA__S_
#  - somewhere later contains _R1_ or _R2_
#  - ends with .fastq or .fastq.gz (fq allowed too)
name_regex='^DW-63-[0-9]+__RNA__S_.*_R[12]_.*\.(fastq|fq)(\.gz)?$'

fail_umi=()
fail_name=()
checked=0

# Helper: print the first FASTQ header line (works for .gz or plain)
first_header() {
  # Prints exactly the first line of the file
  zcat -f -- "$1" 2>/dev/null | head -n 1
}

for f in "${DIR}"/*.{fastq,fq,fastq.gz,fq.gz}; do
  [[ -e "$f" ]] || continue
  ((checked++))

  # ---- Filename check ----
  base="$(basename "$f")"
  if ! [[ "$base" =~ $name_regex ]]; then
    fail_name+=("$base")
  fi

  # ---- UMI/header check ----
  hdr="$(first_header "$f" || true)"
  if [[ -z "${hdr}" ]]; then
    fail_umi+=("$base (empty/unreadable)")
    continue
  fi

  # Take token before any space, then split on colons
  first_token="${hdr%% *}"
  # Count colon-separated fields
  IFS=':' read -r -a fields <<< "$first_token"
  if (( ${#fields[@]} < 8 )); then
    fail_umi+=("$base (found ${#fields[@]} fields, expected ≥8)")
    continue
  fi

  umi="${fields[7]}"  # 0-based index; 7 = 8th field
  # Validate 12-mer with A/C/G/T/N only
  if [[ ! "$umi" =~ ^[ACGTN]{12}$ ]]; then
    fail_umi+=("$base (bad UMI: '$umi')")
  fi
done

if (( checked == 0 )); then
  echo "No FASTQ files found in: $DIR"
  exit 3
fi

echo "Checked $checked FASTQ file(s) in: $DIR"
echo

status=0

if ((${#fail_umi[@]} > 0)); then
  status=1
  echo "❌ UMI/header check FAILED for ${#fail_umi[@]} file(s):"
  for x in "${fail_umi[@]}"; do
    echo "  - $x"
  done
  echo
else
  echo "✅ UMI/header check passed for all files."
fi

if ((${#fail_name[@]} > 0)); then
  status=1
  echo "❌ Filename pattern check FAILED for ${#fail_name[@]} file(s):"
  echo "   Expected to loosely match: DW-63-<digits>__RNA__S_..._R1_/R2_... .fastq[.gz]"
  echo "   Examples flagged (adjust regex in script if needed):"
  for x in "${fail_name[@]}"; do
    echo "  - $x"
  done
  echo
else
  echo "✅ Filename pattern check passed for all files."
fi

if (( status == 0 )); then
  echo "🎉 All clear — filenames and UMIs look good."
else
  echo "⚠️  Issues detected. Review the above files before running your pipeline."
fi

exit "$status"
