#!/bin/bash
bash /root/anonlib-pass28/tools/cell_ab_job.sh nvidia emb "embedding" "embedding" "check-embedding" -
bash /root/anonlib-pass29/tools/cell_ab_job.sh nvidia moe "x_sequence" "moe" "" ANONLIB_SEQ_MOE_TILED=0
