#!/bin/sh
# tools/gemm_price_shipped_leg.sh -- the price-shipped noise control alone
# (DEVIATION 2707's gate had it exit 1 on a harness PHASE routing bug, fixed in
# bench/gemm_step_price_main.mojo). Builds and runs the step leg with only the
# `shipped` price arm and no LM probe; the check still runs. POSIX sh.
set -u
ANONLIB_GEMM_STEP_LEG_ARMS=shipped
ANONLIB_GEMM_STEP_LEG_LM_ARMS=kpack_hg
ANONLIB_GEMM_STEP_LEG_SKIP_LM=1
ANONLIB_GEMM_STEP_LEG_CHECK_ARMS=shipped,kpack_hg
ANONLIB_GEMM_STEP_LEG_OUT=${ANONLIB_GEMM_STEP_LEG_OUT:-/root/gemm_leg_out/gemm-price-shipped}
export ANONLIB_GEMM_STEP_LEG_ARMS ANONLIB_GEMM_STEP_LEG_LM_ARMS ANONLIB_GEMM_STEP_LEG_SKIP_LM \
    ANONLIB_GEMM_STEP_LEG_CHECK_ARMS ANONLIB_GEMM_STEP_LEG_OUT
cd "${ANONLIB_GEMM_STEP_ROOT:-/root/anonlib}" || exit 9
exec sh tools/gemm_step_leg.sh
