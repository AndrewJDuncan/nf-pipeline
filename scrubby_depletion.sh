#!/bin/bash
set -euo pipefail

# ===== Activate Environment =====
source ~/miniforge3/etc/profile.d/conda.sh
mamba activate rna-tools

# ===== Config =====
IN_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate"
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
SCRUBBY_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/scrubby_clean"
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
THREADS=16
SCRUBBY_INDEX="${REFERENCE_DIR}/controls.fasta"
GENOME="GRCh37"
SCRUBBY_ENV="rna-tools"

mkdir -p "$SCRUBBY_DIR"
mkdir -p "$OUTDIR"

# ===== Step 1: Run Scrubby in mamba env =====
echo "[Step 1] Running Scrubby to remove synthetic controls"

# Activate mamba environment for Scrubby
echo "  Activating $SCRUBBY_ENV"
source ~/miniforge3/etc/profile.d/conda.sh
conda activate "$SCRUBBY_ENV"

for r1 in "${IN_DIR}"/*RNA__S_*R1_001.fastq.gz; do
    sample=$(basename "$r1" _R1_001.fastq.gz)
    r2="${sample}_R2_001.fastq.gz"

    if [[ ! -f "$r2" ]]; then
        echo "  Skipping $sample: $r2 not found"
        continue
    fi

    echo "  Scrubbing $sample"
    scrubby reads \
        -i "$r1" -i "$r2" \
        --index "$SCRUBBY_INDEX" \
        --aligner minimap2 \
        --threads "$THREADS" \
        -o "${SCRUBBY_DIR}/${sample}__clean__R1.fq.gz" \
        -o "${SCRUBBY_DIR}/${sample}__clean__R2.fq.gz" \
        --json "${SCRUBBY_DIR}/${sample}.clean.json"
done

echo "Depletion of EDCC / ERCC controls complete"
