#!/bin/bash
set -euo pipefail

# ===== Configuration =====
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
THREADS=16
SCRUBBY_INDEX="${REFERENCE_DIR}/controls.fasta"
INDIR="~/projects/nf-pipeline/validation_plate"
GENOME="GRCh37"
SCRUBBY_DIR="scrubby_clean"

# ===== ERCC/EDCC depletion =====
echo "[Scrubby] Depleting synthetic controls using Scrubby"
mkdir -p "$SCRUBBY_DIR"
mamba activate rna-tools

for r1 in *RNA__S_*R1_001.fastq.gz; do
    sample=$(basename "$r1" _R1_001.fastq.gz)
    r2="${sample}_R2_001.fastq.gz"

    # Skip if R2 not found
    if [[ ! -f "$r2" ]]; then
        echo "  Skipping $sample: $r2 not found"
        continue
    fi

    echo "  Processing $sample"

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
