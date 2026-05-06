#!/bin/bash
set -euo pipefail

REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
THREADS=32
SCRUBBY_INDEX="${REFERENCE_DIR}/controls.fasta"
INDIR="$HOME/projects/ground_truth/naive_vs_Th1/fastqs"
SCRUBBY_DIR="${INDIR}/scrubby_clean"

echo "[Scrubby] Depleting synthetic controls using Scrubby"

mkdir -p "$SCRUBBY_DIR"
cd "$INDIR"

shopt -s nullglob  # prevents literal glob issue

for r1 in *RNA__PS_*R1_001.fastq.gz; do
    sample=$(basename "$r1" _R1_001.fastq.gz)
    r2="${sample}_R2_001.fastq.gz"

    if [[ ! -f "$r2" ]]; then
        echo "  Skipping $sample: $r2 not found"
        continue
    fi

    echo "  Processing $sample"

    scrubby reads \
    -i "$r1" "$r2" \
    --index "$SCRUBBY_INDEX" \
    --threads "$THREADS" \
    -o "${SCRUBBY_DIR}/${sample}__clean__R1.fq.gz" "${SCRUBBY_DIR}/${sample}__clean__R2.fq.gz" \
    --json "${SCRUBBY_DIR}/${sample}.clean.json"

done

echo "Depletion of ERCC controls complete"
