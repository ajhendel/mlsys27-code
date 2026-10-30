#!/bin/sh
# tools/classical_two_datasets_leg2.sh -- the second lease of DEVIATION 2570's
# classical leg: kde and svc (no torch arm) by default. tools/do_extra_leg.sh
# passes no environment to a body, so the lane list lives here; everything
# else is tools/classical_two_datasets_leg.sh.
#
#   ANONLIB_DO_TOKEN_FILE=$HOME/.anonlib_do_token \
#   ANONLIB_GPU_ARCHS=gfx942 \
#   ANONLIB_GEMM_LEG_EXTRA=tools/classical_two_datasets_leg2.sh \
#   ANONLIB_GEMM_LEG_OUT=$HOME/anonlib-evidence/classical-two-datasets-$(date -u +%Y-%m-%d_%H%M%S)-amd-leg2 \
#   bash tools/do_extra_leg.sh amd --minutes 60 --skip-gates
#
# On NVIDIA (RunPod) the leg is driven phase by phase with
# ANONLIB_CTD_LANES=kde,svc set directly (tools/classical_two_datasets_leg.sh
# header, bench/results/classical_h100_2026-09-11/batchB*.sh).
ANONLIB_CTD_LANES=${ANONLIB_CTD_LANES:-kde,svc}
export ANONLIB_CTD_LANES
exec sh /root/anonlib/tools/classical_two_datasets_leg.sh
