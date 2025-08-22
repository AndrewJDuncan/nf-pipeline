# v1.13 - take working v1.12 and reduce stringency to reduce dropout from csf data

# assumes initial scrubby-based ERCC/EDCC cleaning, inside mamba rna-tools environment. Then turn this environment off and run pipeline from mamba nextflow25 environment. 
  ## Skips deseq2_qc - bug
  ## specifies strandedness to reduce misattributed strandedness and nonalignment
  ## ensures --with_umi enabled

#!/bin/bash
set -euo pipefail

# ===== Config =====
IN_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate"
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
SCRUBBY_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate/scrubby_clean"
OUTDIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate/nextflow_output"
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

    # Explicit strandedness (R1 forward)
    echo "${sample},${r1},${r2},forward" >> samples.csv
done

# ===== Step 3: Run nf-core/rnaseq pipeline with conda profile =====
echo "[Step 3] Running nf-core/rnaseq with --profile conda"
nextflow run nf-core/rnaseq \
    -profile conda \
    --input samples.csv \
    --outdir "$OUTDIR" \
    --genome "$GENOME" \
    --with_umi \
    --skip_umi_extract \
    --umitools_umi_separator ":" \
    --remove_ribo_rna \
    --trimmer trimgalore \
    --extra_trimgalore_args "--quality 15 --length 20" \
    --min_trimmed_reads 3000 \
    --min_mapped_reads 1 \
    --skip_deseq2_qc \
    --skip_dupradar \
    --skip_preseq \
    --save_trimmed \
    --save_non_ribo_reads \
    --save_unaligned \
    --save_umi_intermeds \
    -with-report "$OUTDIR/pipeline_report.html" \
    -with-trace "$OUTDIR/pipeline_trace.txt" \
    -with-timeline "$OUTDIR/pipeline_timeline.html" \
    -with-dag "$OUTDIR/pipeline_flowchart.dot"

echo "[Done] Pipeline complete. Output in $OUTDIR"
  
# NOTE: no --pseudo_aligner salmon here (STAR+Salmon already happens with the default --aligner star_salmon)



echo "[Done] Pipeline complete. Output in $OUTDIR"
