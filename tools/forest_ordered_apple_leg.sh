#!/bin/sh
# Local Apple Metal A/B for the ordered resident IDENTICAL forest route.
set -eu
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
OUT=${ANONLIB_FOREST_APPLE_OUT:-/tmp/anonlib-forest-ordered-apple}
BINS="$OUT/bins"
MODELS="$OUT/models"
TIER="$ROOT/python/anonlib/identical"
PY="$ROOT/.pixi/envs/default/bin/python3"
OUTERS=${ANONLIB_FOREST_ORDERED_OUTERS:-3}
ROUNDS=${ANONLIB_FOREST_ORDERED_ROUNDS:-5}
ROWS=${ANONLIB_FOREST_ORDERED_ROWS:-250000}
TRAIN_ROWS=${ANONLIB_FOREST_ORDERED_TRAIN_ROWS:-250000}
mkdir -p "$OUT" "$BINS/sequential" "$BINS/ordered" "$MODELS"
cd "$ROOT"
export ANONLIB_NUMERIC_MODE=identical ANONLIB_TARGET_COLUMN=apple
export ANONLIB_SKIP_BUILD_GATE=1 GBM_BENCH_DATA="${GBM_BENCH_DATA:-$HOME/datasets/gbm-bench}"

build() {
    _name=$1; _defines=$2
    ANONLIB_EXTRA_DEFINES="$_defines" tools/with_build_lock.sh sh bindings/build_rf.sh \
        > "$OUT/build.$_name.rf.log" 2>&1
    cp "$TIER/_anonlib_rf.so" "$BINS/$_name/"
    ANONLIB_EXTRA_DEFINES="$_defines" tools/with_build_lock.sh sh bindings/build_trees.sh \
        > "$OUT/build.$_name.trees.log" 2>&1
    cp "$TIER/_anonlib_trees.so" "$BINS/$_name/"
}
use() {
    cp "$BINS/$1/_anonlib_rf.so" "$TIER/"
    cp "$BINS/$1/_anonlib_trees.so" "$TIER/"
}

if [ "${ANONLIB_FOREST_SKIP_BUILDS:-0}" != 1 ]; then
    tools/with_build_lock.sh sh bindings/build.sh > "$OUT/build.base.log" 2>&1
    build sequential ""
    build ordered "-D ANONLIB_FOREST_ORDERED_RESIDENT=1"
fi
use sequential
PYTHONPATH=python "$PY" -u bench/speed/forest_ordered_resident_ab.py prepare \
    --out "$MODELS" --train-rows "$TRAIN_ROWS" > "$OUT/prepare.log" 2>&1

outer=1
while [ "$outer" -le "$OUTERS" ]; do
    if [ $((outer % 2)) -eq 1 ]; then order="sequential ordered"; else order="ordered sequential"; fi
    for arm in $order; do
        use "$arm"
        for dataset in taxi istella; do
            PYTHONPATH=python "$PY" -u bench/speed/forest_ordered_resident_ab.py run \
                --dataset "$dataset" --arm "$arm" --models "$MODELS" --outer "$outer" \
                --rounds "$ROUNDS" --rows "$ROWS" --json "$OUT/$dataset.$arm.o$outer.json" \
                > "$OUT/run.$outer.$arm.$dataset.log" 2>&1
        done
    done
    outer=$((outer + 1))
done
PYTHONPATH=python "$PY" bench/speed/forest_ordered_resident_ab.py summarize \
    "$OUT"/'*.o*.json' --outers "$OUTERS" --out "$OUT/verdict.json" > "$OUT/summary.log"
use sequential
cat "$OUT/verdict.json"
