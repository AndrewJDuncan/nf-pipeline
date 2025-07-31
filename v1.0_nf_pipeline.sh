## Nextflow rna-seq pipeline 
# Due to low host RNA biomass, uses Eike's <scrubby> to deplete ERCC / EDCC (high % of data from synthetic controls)

# 1. Define directories
  REFERENCE_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/rna_pipeline/references"
  THREADS=32

# 2. Activate environment
  mamba activate nextflow25

# 3. deplete synthetic controls with scrubby
scrubby reads -i $forward -i $reverse --index controls.fasta --aligner minimap2 --threads 16 -o ${sampleID}__clean__R1.fq.gz -o ${sampleID}__clean__R2.fq.gz --json ${sampleID}.clean.json

# Create the sample file for all samples marked as "S"
  echo "sample,fastq_1,fastq_2,strandedness" > samples.csv
  for f in *RNA__S_*R1_001.fastq.gz; do name=$(basename $f _R1_001.fastq.gz); echo "${name},${name}_R1_001.fastq.gz,${name}_R2_001.fastq.gz,auto" >> samples.csv; done

# Run the pipeline with UMI tools and skipping failing Deseq2 scripts:
  nextflow run -r 3.19.0 nf-core/rnaseq -profile conda --input samples.csv --outdir test --genome GRCh37 --with_umi --umitools_umi_separator ":" --skip_umi_extract --skip_deseq2_qc
