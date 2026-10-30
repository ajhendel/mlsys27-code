#!/bin/sh
# Focused local builds and adapter smoke; no cross-vendor qualification.
set -eu
cd "$(dirname "$0")/.."
if [ "${ANONLIB_BUILD_LOCK_HELD:-0}" != 1 ]; then
    exec tools/with_build_lock.sh sh "$0" "$@"
fi
out=${1:-bench/results/gbdt_adapters_local}
mkdir -p "$out"
ANONLIB_PYTHON=${ANONLIB_PYTHON:-"$PWD/checks/pipeline_python.sh"}
export ANONLIB_PYTHON
for mode in fast identical; do
    ANONLIB_NUMERIC_MODE=$mode sh bindings/build_gbdt.sh > "$out/binding-$mode.build.log" 2>&1
    case "$mode" in
        fast) so=python/anonlib/_anonlib_gbdt.so; code=0 ;;
        identical) so=python/anonlib/identical/_anonlib_gbdt.so; code=1 ;;
    esac
    checks/pipeline_python.sh checks/gbdt_binary_prediction_smoke.py "$so" "$code" > "$out/native-$mode.smoke.log" 2>&1
done
PYTHONPATH=python checks/pipeline_python.sh checks/gbdt_adapters_smoke.py > "$out/public.smoke.log" 2>&1
cat "$out/public.smoke.log"
