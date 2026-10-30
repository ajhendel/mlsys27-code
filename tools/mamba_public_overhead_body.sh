#!/bin/sh
# Guarded provider body. Data must already be staged from the two R2 objects.
set -eu
[ "${ANONLIB_MAMBA_PUBLIC_GUARD:-}" = R2_TAXI_ISTELLA ] || { echo 'set ANONLIB_MAMBA_PUBLIC_GUARD=R2_TAXI_ISTELLA' >&2; exit 64; }
ROOT=${ANONLIB_MAMBA_PUBLIC_ROOT:-/root/anonlib}; OUT=${ANONLIB_MAMBA_PUBLIC_OUT:-/root/mamba-public}; DATA=${GBM_BENCH_DATA:-$HOME/datasets/gbm-bench}
case "${ANONLIB_TARGET_COLUMN:-}" in nvidia|amd) ;; *) echo 'target column must be nvidia or amd' >&2; exit 2;; esac
cd "$ROOT"; export PATH="$HOME/.pixi/bin:$PATH" PYTHONPATH="$ROOT/python:$ROOT" ANONLIB_NUMERIC_MODE=identical
if [ -n "${ANONLIB_COMMIT:-}" ]; then COMMIT=$ANONLIB_COMMIT
elif [ -f SHIPPED_COMMIT.txt ]; then COMMIT=$(cat SHIPPED_COMMIT.txt)
elif [ -f ANONLIB_COMMIT ]; then COMMIT=$(cat ANONLIB_COMMIT)
else COMMIT=$(git rev-parse HEAD); fi
mkdir -p "$OUT/logs"; sh bindings/build_mamba.sh >"$OUT/logs/build.log" 2>&1
for row in "taxi:$DATA/taxi/taxi_speed.npz:gbm-bench/taxi/taxi_speed.npz:10d5d35f376a5b2ad5c66fabe624ee2caafb58bc5e7516824f801de9aab6cc15" "istella:$DATA/istella/istella_speed.npz:gbm-bench/istella/istella_speed.npz:31f042376c0b819fe169cbbd998e840567c23dae25c14cb9054b460292f6ffef"; do
 ds=${row%%:*}; rest=${row#*:}; path=${rest%%:*}; rest=${rest#*:}; key=${rest%%:*}; sha=${rest#*:}
 sh tools/dataset_store.sh verify "$key" "$path" >"$OUT/logs/verify-$ds.log" 2>&1
 for family in mamba2 mamba3; do
  for rung in screen qualification; do
   [ "$rung" = screen ] && processes=1 || processes=3
   p=0; while [ "$p" -lt "$processes" ]; do
    dest="$OUT/$rung/$ds/$family/process$p"; mkdir -p "$dest"
    pixi run python tools/mamba_public_overhead_trial.py --family "$family" --rung "$rung" --dataset "$path" --dataset-key "$key" --dataset-sha256 "$sha" --commit "$COMMIT" --process "$p" --target-column "$ANONLIB_TARGET_COLUMN" --out "$dest/result.json" >"$dest/probe.log" 2>&1
    p=$((p+1))
   done
  done
  dest="$OUT/sabotage/$ds/$family"; mkdir -p "$dest"
  pixi run python tools/mamba_public_overhead_trial.py --family "$family" --rung screen --dataset "$path" --dataset-key "$key" --dataset-sha256 "$sha" --commit "$COMMIT" --process 0 --target-column "$ANONLIB_TARGET_COLUMN" --sabotage wrong-token --rounds 1 --out "$dest/result.json" >"$dest/probe.log" 2>&1
 done
done
pixi run python tools/mamba_public_overhead_summary.py --root "$OUT" --out "$OUT/summary.json" | tee "$OUT/summary.txt"
