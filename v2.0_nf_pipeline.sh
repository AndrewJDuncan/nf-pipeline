#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# ==============================================================================
# nf-core/rnaseq (STAR -> RSEM) runner
# - Builds samplesheet from FASTQs in a directory
# - Optionally runs only a subset (first N samples)
# - Ignores UMIs entirely
#
# Output gene counts (matrix):
#   <OUTDIR>/star_rsem/rsem.merged.gene_counts.tsv
#   <OUTDIR>/star_rsem/rsem.merged.gene_tpm.tsv
# See nf-core output docs. (STAR via RSEM) :contentReference[oaicite:2]{index=2}
# ==============================================================================

# ===== Config =====
PROJECT_DIR="/raid/VIDRL-USERS/HOME/aduncan/projects/nf-pipeline/FASTQs_for_processing/valp20250619"
IN_DIR="$PROJECT_DIR"   # FASTQs live here
OUTDIR="$PROJECT_DIR/standard_nextflow_output_star_rsem"

# Use the same genome key you were using previously (assumes nf-core iGenomes config etc. is set up)
GENOME="GRCh38"

# Resources / Nextflow
THREADS=16

# Trial subset controls
N_SAMPLES=6        # set to 0 to include all discovered samples
SUBSET_MODE="first"  # currently only "first" is implemented

# Housekeeping
RUN_NAME="star_rsem_no_umi_$(date +%Y%m%d_%H%M%S)"
SHEET="$OUTDIR/samplesheet.csv"
LOGDIR="$OUTDIR/run_logs"
NF_WORKDIR="$OUTDIR/work"   # keep work in OUTDIR to make cleanup safer

# If you want to keep work for debugging, set CLEAN_WORK=false
CLEAN_WORK=true

# ===== Helpers =====
die() { echo "[FATAL] $*" >&2; exit 1; }
info() { echo -e "[INFO] $*"; }
step() { echo -e "\n========== $* ==========\n"; }

# ===== Setup =====
mkdir -p "$OUTDIR" "$LOGDIR" "$NF_WORKDIR"
cd "$PROJECT_DIR"

# Conda activation for non-interactive shells - e.g. nohup
source "$HOME/miniforge3/etc/profile.d/conda.sh"
conda activate nextflow25

command -v nextflow >/dev/null || die "nextflow not found on PATH."
command -v java      >/dev/null || die "Java not found on PATH."

info "Run name:   $RUN_NAME"
info "Project:    $PROJECT_DIR"
info "Input dir:  $IN_DIR"
info "Outdir:     $OUTDIR"
info "Genome:     $GENOME"
info "Threads:    $THREADS"
info "Subset:     N_SAMPLES=$N_SAMPLES (0 = all)"

# ===== Step 1: Build samplesheet =====
step "Step 1 - Creating nf-core/rnaseq samplesheet"

echo "sample,fastq_1,fastq_2,strandedness" > "$SHEET"

# Collect R1 files deterministically
mapfile -t R1_FILES < <(ls -1 "$IN_DIR"/*_R1_001.fastq.gz 2>/dev/null | sort -V)
[[ "${#R1_FILES[@]}" -gt 0 ]] || die "No '*_R1_001.fastq.gz' files found in $IN_DIR"

count_written=0

for r1 in "${R1_FILES[@]}"; do
  base="$(basename "$r1")"
  r2="${r1/_R1_/_R2_}"

  if [[ ! -f "$r2" ]]; then
    echo "  [warn] Skipping $base: matching R2 not found" >&2
    continue
  fi

  # Sample name = prefix before "__RNA__"
  # e.g. DW-63-V02__RNA__S_S550_R1_001.fastq.gz -> DW-63-V02
  sample="${base%%__RNA__*}"

  echo "${sample},${r1},${r2},auto" >> "$SHEET"
  count_written=$((count_written + 1))

  # Subset logic
  if [[ "$N_SAMPLES" -gt 0 && "$SUBSET_MODE" == "first" && "$count_written" -ge "$N_SAMPLES" ]]; then
    break
  fi
done

[[ "$count_written" -gt 0 ]] || die "Samplesheet ended up empty (no valid R1/R2 pairs)."

info "Samplesheet written: $SHEET"
info "Samples included:    $count_written"

# ===== Step 2: Run nf-core/rnaseq with STAR -> RSEM =====
step "Step 2 - Running nf-core/rnaseq (STAR -> RSEM), ignoring UMIs"

# Notes:
# - --aligner star_rsem selects STAR alignment + RSEM quantification. :contentReference[oaicite:3]{index=3}
# - Do NOT set --with_umi (we are ignoring UMIs entirely)
# - Duplicate handling: nf-core marks duplicates by default (Picard MarkDuplicates). :contentReference[oaicite:4]{index=4}

# Use -resume to allow reruns without redoing everything
# If you prefer a clean run each time, remove -resume and change RUN_NAME/OUTDIR.
nextflow run nf-core/rnaseq \
  -profile conda \
  -name "$RUN_NAME" \
  -resume \
  -work-dir "$NF_WORKDIR" \
  --input "$SHEET" \
  --outdir "$OUTDIR" \
  --genome "$GENOME" \
  --aligner star_rsem \
  --skip_deseq2_qc \
  --max_cpus "$THREADS" \
  -with-report "$LOGDIR/${RUN_NAME}.report.html" \
  -with-timeline "$LOGDIR/${RUN_NAME}.timeline.html" \
  -with-trace "$LOGDIR/${RUN_NAME}.trace.txt" \
  -with-dag "$LOGDIR/${RUN_NAME}.dag.png" \
  > "$LOGDIR/${RUN_NAME}.stdout.log" \
  2> "$LOGDIR/${RUN_NAME}.stderr.log"

step "Done - Outputs"

info "RSEM gene counts matrix should be here:"
info "  $OUTDIR/star_rsem/rsem.merged.gene_counts.tsv"
info "RSEM gene TPM matrix should be here:"
info "  $OUTDIR/star_rsem/rsem.merged.gene_tpm.tsv"
# Output paths per nf-core docs. :contentReference[oaicite:5]{index=5}

# ===== Optional: tidy work directory =====
if [[ "$CLEAN_WORK" == true ]]; then
  step "Tidying up work directory (can be huge)"
  # This cleans Nextflow cache for this run; work-dir is inside OUTDIR anyway.
  nextflow clean -f -q || true
  info "Work directory cleaned."
else
  info "CLEAN_WORK=false, leaving work directory in place:"
  info "  $NF_WORKDIR"
fi

info "All done."
