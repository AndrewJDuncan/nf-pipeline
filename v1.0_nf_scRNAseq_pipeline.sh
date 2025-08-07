# Pipeline for levaraging of incidental human host transcriptomic data from CSF mNGS 
# trial of scRNAseq to compare pipeline outputs

# initial scrubby-based ERCC/EDCC cleaning, run inside mamba rna-tools environment; scrubby shell must run from within sample fastq directory
# then activeate nextflow25 environment, use scrubby output as input for nf-core scRNAseq pipeline. 

#!/bin/bash
set -euo pipefail

# ===== Config =====
IN_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate"
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
SCRUBBY_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate/scrubby_clean"
OUTDIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/pipeline_output/scRNAseq_nf_output"
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
THREADS=16
SCRUBBY_INDEX="${REFERENCE_DIR}/controls.fasta"
GENOME="GRCh37"

mkdir -p "$OUTDIR"

echo "Pipeline initialising"

# ===== Create samplesheet =====
echo "Creating nf-core/rnaseq samplesheet"
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

# ===== Run nf-core/scrnaseq pipeline with conda profile =====
echo "Running nf-core/scrnaseq with --profile test"

SAMPLESHEET="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/samples.csv"

nextflow run nf-core/scrnaseq \
    --input "$SAMPLESHEET" \
    --outdir "$OUTDIR" \
    --aligner star \
    --genome "$GENOME" \
    -profile test
    
mv /raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/samples.csv raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/run_samplesheets/

echo "[Done] Pipeline complete. Output in $OUTDIR"
