# Uses initial scrubby-based ERCC/EDCC cleaning, inside mamba environment, then turns this environment off and runs nf-core nextflow pipeline. 
  ## Skips deseq2_qc - bug
  ## must 

#!/bin/bash
set -euo pipefail

# ===== Config =====
IN_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate"
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
SCRUBBY_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate/scrubby_clean"
OUTDIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate/nextflow_output"
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
THREADS=16
SCRUBBY_INDEX="${REFERENCE_DIR}/controls.fasta"
GENOME="GRCh37"

mkdir -p "$SCRUBBY_DIR"
mkdir -p "$OUTDIR"

echo "Pipeline initialising"


# ===== Step 2: Create samplesheet =====
echo "[Step 2] Creating nf-core/rnaseq samplesheet"
echo "sample,fastq_1,fastq_2,strandedness" > samples.csv

for r1 in ${SCRUBBY_DIR}/*__clean__R1.fq.gz; do
    sample=$(basename "$r1" __clean__R1.fq.gz)
    r2="${SCRUBBY_DIR}/${sample}__clean__R2.fq.gz"

    if [[ ! -f "$r2" ]]; then
        echo "  Skipping $sample in samplesheet: R2 missing"
        continue
    fi

    echo "${sample},${r1},${r2},auto" >> samples.csv
done

# ===== Step 3: Run nf-core/rnaseq pipeline with conda profile =====
echo "[Step 3] Running nf-core/rnaseq with --profile conda"
nextflow run nf-core/rnaseq \
    -profile conda \
    --input samples.csv \
    --outdir "$OUTDIR" \
    --genome "$GENOME" \
    --with_umi \
    --umitools_umi_separator ":" \
    --skip_umi_extract \
    --skip_deseq2_qc

echo "[Done] Pipeline complete. Output in $OUTDIR"
