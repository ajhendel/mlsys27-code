#!/bin/sh
# Compile and exercise native + installed public GPU entry points in all modes.
main() {
set -eu
cd "$(dirname "$0")/.."
if [ "${ANONLIB_BUILD_LOCK_HELD:-}" != 1 ]; then
    exec tools/with_build_lock.sh sh tools/check_min_child_hessian.sh "$@"
fi
ANONLIB_HESSIAN_PYTHON=${ANONLIB_PYTHON:-python3}
export ANONLIB_HESSIAN_PYTHON
ANONLIB_PYTHON="$PWD/checks/min_child_hessian_python.sh"
export ANONLIB_PYTHON
out=${1:-bench/results/min_child_hessian_2026-09-10}
mkdir -p "$out" build/min_child_hessian
pixi run mojo --version > "$out/toolchain.txt"
for mode in fast identical; do
    set --
    if [ "$mode" = identical ]; then set -- -D ANONLIB_NUMERIC_IDENTICAL=1; fi
    echo "BUILD native $mode"
    pixi run mojo build -I . "$@" checks/min_child_hessian_check.mojo \
        -o "build/min_child_hessian/$mode" > "$out/$mode.build.log" 2>&1
    "build/min_child_hessian/$mode" > "$out/$mode.run.log" 2>&1
    echo "PASS native $mode"
    ANONLIB_NUMERIC_MODE=$mode sh bindings/build_gbdt.sh > "$out/binding-$mode.build.log" 2>&1
    PYTHONPATH=python "$ANONLIB_PYTHON" checks/min_child_hessian_binding.py --mode "$mode" > "$out/binding-$mode.run.log" 2>&1
    echo "PASS public $mode"
done
}
main "$@"
