#!/bin/sh
# Guarded Hot Aisle body: exact and timed AMD qualification of the opt-in
# attention-v1 zdot 16x16 schedule.  The runner owns lease and teardown.
set -eu
cd /root/anonlib
OUT=/root/gemm_leg_out/attention-tq16-amd
BIN=/root/attention-tq16-bin
mkdir -p "$OUT" "$BIN"
export PATH="$HOME/.pixi/bin:$PATH"
ARCH=${ANONLIB_GPU_ARCHS:-gfx942}
COMMON="-D ANONLIB_NUMERIC_IDENTICAL=1 -D ANONLIB_COLUMN_AMD -D ANONLIB_ATTN_ARM_TRIAL=1"

# shellcheck disable=SC2086
pixi run mojo build -j 2 --target-accelerator "$ARCH" -I . $COMMON \
    bench/attention_step_price_main.mojo -o "$BIN/base" > "$OUT/build-base.log" 2>&1
# shellcheck disable=SC2086
pixi run mojo build -j 2 --target-accelerator "$ARCH" -I . $COMMON \
    -D ANONLIB_ATTN_ES_TQ16=1 bench/attention_step_price_main.mojo \
    -o "$BIN/tq16" > "$OUT/build-tq16.log" 2>&1

for spec in 1024:0 1536:0 2048:0 2048:512; do
    L=${spec%%:*}
    W=${spec##*:}
    for arm in base tq16; do
        ANONLIB_ATTN_ARM=default ANONLIB_ATTN_BASELINE=default \
        ANONLIB_ATTN_KINDS=hashed ANONLIB_ATTN_L="$L" \
        ANONLIB_ATTN_B=1 ANONLIB_ATTN_NH=12 ANONLIB_ATTN_NKV=12 \
        ANONLIB_ATTN_HD=64 ANONLIB_ATTN_WINDOW="$W" \
        ANONLIB_ATTN_ROUNDS=15 ANONLIB_ATTN_WARMUPS=4 \
        ANONLIB_ATTN_ORACLE=1 ANONLIB_ATTN_REACH=0 \
        ANONLIB_ATTN_RESOURCES=0 "$BIN/$arm" \
            > "$OUT/l${L}_w${W}_${arm}.log" 2>&1
        grep 'attention_step_price: PASS' "$OUT/l${L}_w${W}_${arm}.log"
    done
done

for f in "$OUT"/l*.log; do
    printf 'FILE %s\n' "$(basename "$f")"
    grep '^TABLE stash' "$f" | head -1
    if grep -E 'BITS .* (MOVED|DIFF)' "$f"; then
        echo 'identity mismatch'; exit 1
    fi
done > "$OUT/summary.txt"
cat "$OUT/summary.txt"
