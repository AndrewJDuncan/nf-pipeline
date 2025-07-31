#!/bin/bash
set -euo pipefail

# ===== Configuration =====
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
THREADS=16
SCRUBBY_INDEX="${REFERENCE_DIR}/controls.fasta"
OUTDIR="nextflow_output"
GENOME="GRCh37"
SCRUBBY_DIR="scrubby_clean"

# ===== ERCC/EDCC depletion =====
echo "[Scrubby] Depleting synthetic controls using Scrubby"
mkdir -p "$SCRUBBY_DIR"

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

# ===== Generate nf-core/rnaseq Samplesheet =====
echo "[Nextflow] Generating CSV samplesheet"
echo "sample,fastq_1,fastq_2,strandedness" > samples.csv

for r1 in ${SCRUBBY_DIR}/*__clean__R1.fq.gz; do
    sample=$(basename "$r1" __clean__R1.fq.gz)
    r2="${SCRUBBY_DIR}/${sample}__clean__R2.fq.gz"

    # Confirm R2 exists
    if [[ ! -f "$r2" ]]; then
        echo "  Skipping $sample in samplesheet: R2 missing"
        continue
    fi

    echo "${sample},${r1},${r2},auto" >> samples.csv
done

# ===== Run nf-core/rnaseq Pipeline (with profile=conda) =====
echo "[Nextflow] Running nf-core/rnaseq with --profile conda"

nextflow run nf-core/rnaseq \
    -profile conda \
    --input samples.csv \
    --outdir "$OUTDIR" \
    --genome "$GENOME" \
    --with_umi \
    --umitools_umi_separator ":" \
    --skip_umi_extract \
    --skip_deseq2_qc

echo "[Done] Results in $OUTDIR"
