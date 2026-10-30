#!/bin/sh
# lane/apple-identical-neural (2026-09-26): the cross-vendor body. Run on a
# rented NVIDIA or AMD box from the repo root (tools/gemm_remote_leg.sh via
# ANONLIB_GEMM_LEG_EXTRA, or tools/hotaisle_leg.sh). Proves the branch
# still builds and agrees there:
#   1. gemm_backward_check and gemm_workspace_check (the leg's gemm payload
#      runs gemm_device_check itself on RunPod; this body runs it on Hot Aisle);
#   2. the T3 shard GEMM harness on six operand kinds, whose hashes must equal
#      the Apple M4's (~/anonlib-evidence/apple-identical-neural/hv.txt);
#   3. the byte LM binding built here and four resident lean steps at
#      1 x 2048, d768, 2 layers, V 50,257, witnessed every step; the per-step
#      loss/gradient/parameter/m/v hashes must equal the Apple M4's.
# Everything lands under /root/gemm_leg_out, which the leg fetches home.
set -u
ROOT=$(pwd)
O=/root/gemm_leg_out
mkdir -p "$O"
PATH="$HOME/.pixi/bin:/usr/local/cuda/bin:$PATH"; export PATH
col=${ANONLIB_TARGET_COLUMN:-nvidia}
if [ "$col" = nvidia ]; then
    cc=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d .)
    : "${ANONLIB_GPU_ARCHS:=sm_$cc}"
    D=ANONLIB_COLUMN_NVIDIA
else
    : "${ANONLIB_GPU_ARCHS:=gfx942}"
    D=ANONLIB_COLUMN_AMD
fi
ANONLIB_TARGET_COLUMN=$col
export ANONLIB_GPU_ARCHS ANONLIB_TARGET_COLUMN
export ANONLIB_NUMERIC_MODE=identical PYTHONPATH="$ROOT/python:$ROOT"
say() { echo "[$(date -u +%H:%M:%S)] $*" | tee -a "$O/status.txt"; }
say "column=$col arch=$ANONLIB_GPU_ARCHS"
STEP_ONLY=${ANONLIB_XVENDOR_STEP_ONLY:-0}
checks="gemm_backward_check gemm_workspace_check"
[ "$STEP_ONLY" = 1 ] && checks=""
[ "$col" = amd ] && checks="gemm_device_check $checks"
for c in $checks; do
    if [ "$c" = gemm_workspace_check ]; then
        pixi run mojo run -D ANONLIB_NUMERIC_IDENTICAL=1 -D "$D" --target-accelerator "$ANONLIB_GPU_ARCHS" \
            -D ANONLIB_STEP_PHASE_TIMERS=1 -I . "gemm/checks/$c.mojo" > "$O/$c.log" 2>&1
    else
        pixi run mojo run -D ANONLIB_NUMERIC_IDENTICAL=1 -D "$D" --target-accelerator "$ANONLIB_GPU_ARCHS" \
            -I . "gemm/checks/$c.mojo" > "$O/$c.log" 2>&1
    fi
    say "$c exit=$? $(grep -E 'all green|PASS|FAIL' "$O/$c.log" | tail -1 | cut -c1-160)"
done
if [ "$STEP_ONLY" != 1 ]; then
pixi run mojo build -D ANONLIB_NUMERIC_IDENTICAL=1 -D "$D" --target-accelerator "$ANONLIB_GPU_ARCHS" \
    -I . bench/gemm_excp_ab_main.mojo -o /root/ab > "$O/ab.build.log" 2>&1
say "ab build exit=$?"
ANONLIB_EXCP_AB_KINDS=ordinary,mixed,skew,border,sparse ANONLIB_EXCP_AB_ROUNDS=1 /root/ab > "$O/ab.kinds5.log" 2>&1
say "ab kinds5 exit=$? lines=$(grep -c '^EXCP_AB call' "$O/ab.kinds5.log")"
ANONLIB_EXCP_AB_KINDS=tiny ANONLIB_EXCP_AB_CALLS=proj_fwd,proj_dA,proj_dB,down_fwd ANONLIB_EXCP_AB_ROUNDS=1 \
    /root/ab > "$O/ab.tiny.log" 2>&1
say "ab tiny exit=$? lines=$(grep -c '^EXCP_AB call' "$O/ab.tiny.log")"
fi
# The step probe loads the base binding too (all_finite_f32 and friends).
ANONLIB_NUMERIC_MODE=identical sh bindings/build.sh > "$O/base.build.log" 2>&1
say "base build exit=$?"
rm -f python/anonlib/identical/_anonlib_byte_lm.so
sh bindings/build_byte_lm.sh > "$O/byte_lm.build.log" 2>&1
say "byte_lm build exit=$?"
pixi run python tools/lm_step_memory_probe.py --out "$O/step" --shape 1 2048 768 12 12 64 2048 2 50257 \
    --steps 4 --resident-lean --witness-every-step --budget-seconds 900 > "$O/step.log" 2>&1
say "step exit=$?"
say done
