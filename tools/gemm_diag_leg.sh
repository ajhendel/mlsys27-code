#!/bin/sh
# tools/gemm_diag_leg.sh -- DEVIATION 2705, the on-box body of the GEMM kernel
# DIAGNOSTIC decomposition (bench/gemm_step_diag_main.mojo; brief section 16).
# Builds the diagnostic price binary under the identical + trial + DIAG
# defines, runs it, leaves diag.log and diag.txt in the leg's out dir. No
# dataset, no LM run, nothing shipped, every variant but base wrong by design.
# POSIX sh only.
set -eu
ROOT=${ANONLIB_GEMM_STEP_ROOT:-/root/anonlib}
OUT=${ANONLIB_GEMM_STEP_LEG_OUT:-/root/gemm_leg_out/gemm-diag}
mkdir -p "$OUT"
export PATH="$HOME/.pixi/bin:$PATH"
{
    echo "deviations=2705"
    echo "started=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "root=$ROOT gpu_archs=${ANONLIB_GPU_ARCHS:-unset}"
} > "$OUT/diag.txt"
cd "$ROOT" || { echo "no $ROOT" >> "$OUT/diag.txt"; exit 9; }
nvidia-smi --query-gpu=name,driver_version,clocks.current.sm,temperature.gpu --format=csv > "$OUT/gpu_before.txt" 2>&1
if pixi run mojo build -j 2 --target-accelerator "${ANONLIB_GPU_ARCHS:-sm_90a}" -I . -D ANONLIB_NUMERIC_IDENTICAL=1 -D ANONLIB_GEMM_ARM_TRIAL=1 -D ANONLIB_GEMM_DIAG=1 \
    bench/gemm_step_diag_main.mojo -o "$OUT/step-diag" > "$OUT/build.log" 2>&1; then
    echo "build=0" >> "$OUT/diag.txt"
else
    echo "build=$?" >> "$OUT/diag.txt"; exit 9
fi
for sweep in 1 2; do
    env ANONLIB_GEMM_STEP_ROUNDS="${ANONLIB_GEMM_STEP_ROUNDS:-11}" ANONLIB_GEMM_STEP_WARMUPS="${ANONLIB_GEMM_STEP_WARMUPS:-2}" \
        "$OUT/step-diag" > "$OUT/diag-$sweep.log" 2>&1
    echo "run-$sweep=0" >> "$OUT/diag.txt"
done
nvidia-smi --query-gpu=name,driver_version,clocks.current.sm,temperature.gpu --format=csv > "$OUT/gpu_after.txt" 2>&1
echo "finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUT/diag.txt"
grep -h '^DIAG_BEGIN\|^DIAG \|^DIAGSTEP\|^DIAG_DONE' "$OUT"/diag-*.log >> "$OUT/diag.txt"
rm -f "$OUT/step-diag"
