#!/usr/bin/env bash
set -euo pipefail

in_fq="$1"     # input .fq.gz
out_fq="$2"    # output .fq.gz
sep="_"        # separator to use between readname and UMI

zcat "$in_fq" | awk -v sep="$sep" '
  NR%4==1 {
    # Split line into: first token (read id) and the rest (pair info etc.)
    readid=$1
    rest=""
    if (NF>1) {
      # reconstruct remainder of line exactly (space-separated fields)
      for (i=2; i<=NF; i++) rest = rest (i==2 ? "" : OFS) $i
    }

    # Find last ":" in readid
    pos = match(readid, /:[^:]+$/)
    if (pos == 0) {
      # No colon segment found - leave unchanged
      print $0
      next
    }

    umi = substr(readid, RSTART+1)             # after last ":"
    base = substr(readid, 1, RSTART-1)         # before last ":"

    new_readid = base sep umi

    if (rest != "") print new_readid " " rest
    else           print new_readid
    next
  }
  { print }
' | gzip -c > "$out_fq"
