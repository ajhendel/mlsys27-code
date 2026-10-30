#!/bin/sh
set -eu
exec sh "${ANONLIB_GEMM_STEP_ROOT:-/root/anonlib}/tools/gemm_stage_training_leg.sh" enwik8
