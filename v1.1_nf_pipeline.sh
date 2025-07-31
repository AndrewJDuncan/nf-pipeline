# Uses initial scrubby-based ERCC/EDCC cleaning, inside mamba environment, then turns this environment off and runs nf-core nextflow pipeline. 
  ## Skips deseq2_qc - bug

#!/bin/bash
set -euo pipefail

# ===== Config =====
IN_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/validation_plate"
REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/references"
SCRUBBY_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/scrubby_clean"
OUTDIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/nextflow_output"
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

# Deactivate env
echo "  Deactivating Scrubby env"
mamba deactivate

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

# ===== Step 4: Generate Read Count Summary =====
echo "[Step 4] Generating read count summary"
SUMMARY_FILE="${OUTDIR}/read_counts_summary.txt"
printf "%-30s %12s %12s %12s\n" "Sample" "RawReads" "ScrubbedReads" "FinalReads" | tee "$SUMMARY_FILE"
printf "%-30s %12s %12s %12s\n" "------" "---------" "-------------" "----------" | tee -a "$SUMMARY_FILE"

for r1 in *RNA__S_*R1_001.fastq.gz; do
    sample=$(basename "$r1" _R1_001.fastq.gz)

    # Define input/output file paths
    raw_r1="$r1"
    scrubbed_r1="${SCRUBBY_DIR}/${sample}__clean__R1.fq.gz"
    bam_file="${OUTDIR}/results/star_align/${sample}/${sample}.sorted.bam"

    # Get raw read count (R1 only, since paired)
    raw_reads=$(zcat "$raw_r1" | echo $(( $(wc -l) / 4 )) )

    # Get scrubbed read count
    if [[ -f "$scrubbed_r1" ]]; then
        scrubbed_reads=$(zcat "$scrubbed_r1" | echo $(( $(wc -l) / 4 )) )
    else
        scrubbed_reads="NA"
    fi

    # Get final read count from BAM
    if [[ -f "$bam_file" ]]; then
        final_reads=$(samtools view -c -F 0x900 "$bam_file")  # exclude secondary/supplementary
    else
        final_reads="NA"
    fi

    # Output row
    printf "%-30s %12s %12s %12s\n" "$sample" "$raw_reads" "$scrubbed_reads" "$final_reads" | tee -a "$SUMMARY_FILE"
done

echo "[Done] Summary saved to $SUMMARY_FILE"

