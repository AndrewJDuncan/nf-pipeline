# Uses initial scrubby-based ERCC/EDCC cleaning, inside mamba environment, then turns this environment off and runs nf-core nextflow pipeline. 
  ## Skips deseq2_qc - bug

#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# ===== Config =====
PROJECT_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/classif_cases"
IN_DIR="$PROJECT_DIR"                                # keep for readability
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
SCRUBBY_DIR="$PROJECT_DIR/scrubby_clean"
OUTDIR="$PROJECT_DIR/standard_nextflow_output"
THREADS=16
GENOME="GRCh37"

# Ensure we’re in a predictable working directory
mkdir -p "$SCRUBBY_DIR" "$OUTDIR"
cd "$PROJECT_DIR"

# Robust conda activation for non-interactive shells
if [[ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]]; then
  # miniforge
  # shellcheck disable=SC1091
  source "$HOME/miniforge3/etc/profile.d/conda.sh"
elif [[ -f "$HOME/mambaforge/etc/profile.d/conda.sh" ]]; then
  # mambaforge
  # shellcheck disable=SC1091
  source "$HOME/mambaforge/etc/profile.d/conda.sh"
else
  echo "[FATAL] Could not find conda.sh under \$HOME/{mini,mamba}forge." >&2
  exit 1
fi

conda activate nextflow25

# Basic sanity checks (helpful when nohup-detached)
command -v nextflow >/dev/null || { echo "[FATAL] nextflow not found on PATH."; exit 1; }
command -v java >/dev/null || { echo "[FATAL] Java not found on PATH."; exit 1; }

echo "Pipeline initialising. Go do your lit review, this'll take a while."

# ===== Step 2: Create samplesheet =====
echo "[Step 2] Creating nf-core/rnaseq samplesheet"
SHEET="$OUTDIR/samples.csv"
echo "sample,fastq_1,fastq_2,strandedness" > "$SHEET"

found_any=false
for r1 in "$SCRUBBY_DIR"/*__clean__R1.fq.gz; do
  sample="$(basename "$r1" __clean__R1.fq.gz)"
  r2="$SCRUBBY_DIR/${sample}__clean__R2.fq.gz"
  if [[ -f "$r2" ]]; then
    echo "${sample},${r1},${r2},auto" >> "$SHEET"
    found_any=true
  else
    echo "  [warn] Skipping $sample in samplesheet: R2 missing" >&2
  fi
done

if [[ "$found_any" = false ]]; then
  echo "[FATAL] No '*__clean__R1.fq.gz' files found in $SCRUBBY_DIR." >&2
  exit 1
fi

# ===== Step 3: Run nf-core/rnaseq =====
echo "[Step 3] Running nf-core/rnaseq with --profile conda"
nextflow run nf-core/rnaseq \
  -profile conda \
  --input "$SHEET" \
  --outdir "$OUTDIR" \
  --genome "$GENOME" \
  --with_umi \
  --umitools_umi_separator ":" \
  --skip_umi_extract \
  --skip_deseq2_qc

echo "[Done] Pipeline complete. Output in $OUTDIR"

# ===== clear work directory (it's huge) =====
echo "Tidying up work directory 🚮"
nextflow clean -f -q || true
echo "All done, now get back out there and have some good clean fun."
