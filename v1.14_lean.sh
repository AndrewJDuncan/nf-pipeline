#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# ===== Config =====
PROJECT_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/FASTQs_for_processing/valp20250619"
IN_DIR="$PROJECT_DIR"                                # raw FASTQs live here
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
OUTDIR="$PROJECT_DIR/standard_nextflow_output_min"
THREADS=16
GENOME="GRCh38"

# Ensure we’re in a predictable working directory
mkdir -p "$OUTDIR"
cd "$PROJECT_DIR"

# Conda activation for non-interactive shells - e.g. nohup
source "$HOME/miniforge3/etc/profile.d/conda.sh"
conda activate nextflow25

# Basic sanity checks
command -v nextflow >/dev/null || { echo "[FATAL] nextflow not found on PATH."; exit 1; }
command -v java      >/dev/null || { echo "[FATAL] Java not found on PATH."; exit 1; }

echo "Pipeline initialising (minimal STAR+Salmon+UMI)."

# ===== Step 2: Create samplesheet from RAW FASTQs =====
echo "[Step 2] Creating nf-core/rnaseq samplesheet from raw FASTQs"

SHEET="$OUTDIR/samples.csv"
echo "sample,fastq_1,fastq_2,strandedness" > "$SHEET"

found_any=false

# Expecting patterns like:
#   DW-63-V02__RNA__S_S550_R1_001.fastq.gz
#   DW-63-V02__RNA__S_S550_R2_001.fastq.gz
for r1 in "$IN_DIR"/*_R1_001.fastq.gz; do
  base="$(basename "$r1")"
  r2="${r1/_R1_/_R2_}"

  if [[ ! -f "$r2" ]]; then
    echo "  [warn] Skipping $base in samplesheet: matching R2 not found" >&2
    continue
  fi

  # Sample name = prefix before "__RNA__"
  sample="${base%%__RNA__*}"

  echo "${sample},${r1},${r2},auto" >> "$SHEET"
  found_any=true
done

if [[ "$found_any" = false ]]; then
  echo "[FATAL] No '*_R1_001.fastq.gz' files found in $IN_DIR." >&2
  exit 1
fi

echo "  Samplesheet written to: $SHEET"

# ===== Step 3: Run nf-core/rnaseq (minimal setup) =====
echo "[Step 3] Running nf-core/rnaseq (trim + UMI + STAR+Salmon, minimal QC)"

nextflow run nf-core/rnaseq \
  -profile conda \
  --input "$SHEET" \
  --outdir "$OUTDIR" \
  --genome "$GENOME" \
  --aligner star_salmon \
  \
  --with_umi \
  --umitools_extract_method string \
  --umitools_bc_pattern NNNNNNNN \
  \
  --skip_qc \
  --skip_deseq2_qc

echo "[Done] Minimal pipeline complete. Output in $OUTDIR"

# ===== clear work directory (it's huge) =====
echo "Tidying up work directory 🚮"
nextflow clean -f -q || true
echo "All done, now go inspect your MultiQC + counts."
