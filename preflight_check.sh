#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Loose naming pattern: DW-63-<digits>__RNA__S_..._R1/2...
name_regex='^DW-63-[0-9]+__RNA__S_.*_R[12]_.*\.(fastq|fq)(\.gz)?$'

fail_umi=()
fail_name=()
checked=0

first_header() {
  zcat -f -- "$1" 2>/dev/null | head -n 1
}

for f in *.{fastq,fq,fastq.gz,fq.gz}; do
  [[ -e "$f" ]] || continue
  ((checked++))

  base="$(basename "$f")"

  # --- Filename check ---
  if ! [[ "$base" =~ $name_regex ]]; then
    fail_name+=("$base")
  fi

  # --- Header/UMI check ---
  hdr="$(first_header "$f" || true)"
  if [[ -z "$hdr" ]]; then
    fail_umi+=("$base (empty/unreadable)")
    continue
  fi

  first_token="${hdr%% *}"
  IFS=':' read -r -a fields <<< "$first_token"
  if (( ${#fields[@]} < 8 )); then
    fail_umi+=("$base (only ${#fields[@]} fields, expected ≥8)")
    continue
  fi

  umi="${fields[7]}"
  if [[ ! "$umi" =~ ^[ACGTN]{12}$ ]]; then
    fail_umi+=("$base (bad UMI: '$umi')")
  fi
done

echo "Checked $checked FASTQ file(s) in $(pwd)"
echo

status=0

if ((${#fail_umi[@]} > 0)); then
  status=1
  echo "❌ UMI/header check failed for:"
  printf '  - %s\n' "${fail_umi[@]}"
  echo
else
  echo "✅ All UMIs look good."
fi

if ((${#fail_name[@]} > 0)); then
  status=1
  echo "❌ Filename pattern check failed for:"
  printf '  - %s\n' "${fail_name[@]}"
  echo
else
  echo "✅ All filenames look good."
fi

if (( status == 0 )); then
  echo "🎉 All clear."
else
  echo "⚠️  Issues detected above."
fi

exit "$status"
