#!/bin/sh
# Final default qualification on both normal corpora, 700 steps per arm.
set -eu
ROOT=/root/anonlib
OUT=/root/gemm_leg_out/lm-attention-default
mkdir -p "$OUT"
cd "$ROOT"
export PATH="$HOME/.pixi/bin:$PATH"
export ANONLIB_NUMERIC_MODE=identical ANONLIB_TARGET_COLUMN=nvidia ANONLIB_GPU_ARCHS=sm_90a
export PYTHONPATH="$ROOT/python:$ROOT"
# --check is read-only: absence or a wrong hash must fail, never download.
sh tools/fetch_corpus_enwik8.sh --check > "$OUT/corpus_enwik8.log"
sh tools/fetch_corpus_pile_github.sh --check > "$OUT/corpus_pile_github.log"
rm -f python/anonlib/identical/_anonlib.so python/anonlib/identical/_anonlib_byte_lm.so
ANONLIB_SKIP_BUILD_GATE=1 sh bindings/build.sh > "$OUT/build_base.log" 2>&1
# Prove the newly added negative-zero-preservation checks reject corrupted GPU outputs.
DEFS="-D ANONLIB_NUMERIC_IDENTICAL=1 -D ANONLIB_COLUMN_NVIDIA"
for site in Z DQ; do
    if pixi run mojo run -j 2 --target-accelerator sm_90a $DEFS -D ANONLIB_CHECK_CORRUPT_${site}_PRESERVE=1 -I . transformer/checks/attention_masked_tail_check.mojo > "$OUT/preserve_sabotage_$site.log" 2>&1; then
        echo "BLIND: preserve $site output corruption passed"; exit 1
    fi
    if [ "$site" = Z ]; then pattern='zdot preserve differs'; else pattern='dq preserve differs'; fi
    grep "$pattern" "$OUT/preserve_sabotage_$site.log"
done
pixi run mojo run -j 2 --target-accelerator sm_90a $DEFS -I . transformer/checks/attention_masked_tail_check.mojo > "$OUT/repair_preserve_gate.log" 2>&1
for arm in legacy released_legacy repaired; do
    rm -f python/anonlib/identical/_anonlib_byte_lm.so
    defines=""
    if [ "$arm" = legacy ]; then defines="-D ANONLIB_ATTN_LEGACY_CORNER=1 -D ANONLIB_BYTE_LM_RETAIN_EAGER=1"; fi
    if [ "$arm" = released_legacy ]; then defines="-D ANONLIB_ATTN_LEGACY_CORNER=1"; fi
    ANONLIB_BUILD_EXTRA_DEFINES="$defines" sh bindings/build_byte_lm.sh > "$OUT/build_$arm.log" 2>&1
    corpora="enwik8 pile_github"
    if [ "$arm" = released_legacy ]; then corpora="enwik8"; fi
    for corpus in $corpora; do
        mkdir -p "$OUT/$corpus"
        pixi run python tools/lm_ce_alias_probe.py --out "$OUT/$corpus/$arm" --steps 700 --tail 0 --corpus "training/corpus/$corpus/input.txt" --smi-every 10 --witness-every 699 > "$OUT/$corpus/$arm.log" 2>&1
        echo "$corpus $arm complete" >> "$OUT/status.txt"
    done
done
for corpus in enwik8 pile_github; do
    pixi run python tools/lm_attention_repair_compare.py "$OUT/$corpus" --default > "$OUT/$corpus/verdict.log" 2>&1
    cat "$OUT/$corpus/verdict.log"
done
pixi run python tools/lm_attention_release_compare.py "$OUT/enwik8" > "$OUT/enwik8/release_verdict.log" 2>&1
cat "$OUT/enwik8/release_verdict.log"
