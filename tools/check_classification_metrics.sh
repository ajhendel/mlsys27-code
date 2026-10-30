#!/bin/sh
# Native and public classification counts and scores in every numeric mode, one device at a time.
set -eu
cd "$(dirname "$0")/.."
if [ "${ANONLIB_BUILD_LOCK_HELD:-}" != 1 ]; then
    exec tools/with_build_lock.sh sh tools/check_classification_metrics.sh "$@"
fi
ANONLIB_PIPELINE_PYTHON=${ANONLIB_PYTHON:-python3}
export ANONLIB_PIPELINE_PYTHON
ANONLIB_PYTHON="$PWD/checks/pipeline_python.sh"
export ANONLIB_PYTHON
out=${1:-bench/results/classification_metrics_local}
mkdir -p "$out" build/classification_metrics
pixi run mojo --version > "$out/toolchain.txt"
for mode in fast identical; do
    set --
    if [ "$mode" = identical ]; then set -- -D ANONLIB_NUMERIC_IDENTICAL=1; fi
    echo "BUILD native $mode"
    pixi run mojo build -I . "$@" metrics/checks/classification_metrics_check.mojo \
        -o "build/classification_metrics/$mode" > "$out/$mode.build.log" 2>&1
    "build/classification_metrics/$mode" > "$out/$mode.run.log" 2>&1
    echo "PASS native $mode"
    ANONLIB_NUMERIC_MODE=$mode sh bindings/build_metrics.sh > "$out/binding-$mode.build.log" 2>&1
    echo "BUILT public $mode"
done
PYTHONPATH=python "$ANONLIB_PYTHON" checks/classification_metrics_binding.py > "$out/public.run.log" 2>&1
echo "PASS public interleaved modes"
