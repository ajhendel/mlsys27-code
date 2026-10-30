#!/bin/sh
# tools/nvidia_step_time/attn_arms.sh -- lane/nvidia-step-time: price attention
# arm words on the lean B4 step at the T3 shape (binding `attntrial`, built
# with -D ANONLIB_ATTN_ARM_TRIAL=1); witnesses must equal the default's.
set -u
cd /root/anonlib || exit 9
PATH="$HOME/.pixi/bin:/usr/local/cuda/bin:$PATH"; export PATH
export ANONLIB_NUMERIC_MODE=identical ANONLIB_TARGET_COLUMN=nvidia ANONLIB_GPU_ARCHS=sm_90a
export PYTHONPATH=/root/anonlib/python:/root/anonlib
OUT=/root/gemm_leg_out/nv-step-time
sh tools/nvidia_step_time/session.sh use attntrial > /dev/null
for arm in ${ARMS:-""}; do
    d="$OUT/attn-$(echo "${arm:-default}" | tr -c 'a-z0-9_\n' '_')"
    rm -rf "$d"
    ANONLIB_ATTN_ARM="$arm" pixi run python tools/lm_step_memory_probe.py --out "$d" \
        --shape 4 2048 768 12 12 64 2048 12 50257 --steps 3 --resident-lean --witness-every-step --budget-seconds 600 > "$d.log" 2>&1
    echo "attn arm=${arm:-default}: $(python3 -c "import json;r=json.load(open('$d/result.json'));print(r['steady_median_seconds'], [w['sha256']['parameters'][:12] for w in r['step_witnesses']])" 2>&1 | tail -1)"
done
