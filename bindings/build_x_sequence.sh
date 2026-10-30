#!/bin/sh
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/build_defines.sh"  # ANONLIB_BUILD_DEFINES -> $ANONLIB_BUILD_DEFINE_FLAGS (compile line)
# The sequence expansion lane's GPU binding (FAST and IDENTICAL).
set -eu
MACOS_FLOOR="11.0"
cd "$(dirname "$0")/.."
if [ "${ANONLIB_BUILD_LOCK_HELD:-}" != 1 ]; then
    exec tools/with_build_lock.sh sh bindings/build_x_sequence.sh "$@"
fi
# Match existing bindings: environment deployment target disables Metal AOT.
unset MACOSX_DEPLOYMENT_TARGET
# TWO TIERS (2026-09-25, reversing DEVIATION 2490 for classical ML): this
# binding builds IDENTICAL (the default, bitwise across vendors) or FAST
# (per-vendor speed, same quality, no bit promise).
mode=${ANONLIB_NUMERIC_MODE:-identical}
mode_flags=""
outdir=python/anonlib
case "$mode" in
    fast) expected=0 ;;
    identical) expected=1; mode_flags="-D ANONLIB_NUMERIC_IDENTICAL=1"; outdir=$outdir/identical ;;
    *) echo "invalid numeric mode: $mode" >&2; exit 2 ;;
esac
link_flags=""
target_flags=""
if [ "$(uname)" = Darwin ]; then
    sdk=$(xcrun --sdk macosx --show-sdk-version)
    link_flags="-Xlinker -platform_version -Xlinker macos -Xlinker $MACOS_FLOOR -Xlinker $sdk"
    target_flags="--target-cpu apple-m1 --target-accelerator metal:1"
else
    case "$(uname -m)" in
        x86_64) target_flags="--target-cpu ${ANONLIB_LINUX_CPU:-x86-64-v3}" ;;
    esac
    if [ -n "${ANONLIB_GPU_ARCHS:-}" ]; then
        case "$ANONLIB_GPU_ARCHS" in *,*) echo "one GPU architecture required" >&2; exit 2 ;; esac
        target_flags="$target_flags --target-accelerator $ANONLIB_GPU_ARCHS"
    fi
fi
column_flags=""
if [ -n "${ANONLIB_TARGET_COLUMN:-}" ]; then
    column_flags="-D ANONLIB_COLUMN_$(printf %s "$ANONLIB_TARGET_COLUMN" | tr '[:lower:]' '[:upper:]')"
fi
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/anonlib-x-sequence.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT INT TERM
out=$tmpdir/_anonlib_x_sequence.so
# Intentionally split compiler option lists, consistent with existing builders.
pixi run mojo build -j "${ANONLIB_COMPILE_JOBS:-2}" --emit shared-lib ${ANONLIB_MOJO_BUILD_FLAGS:-} ${ANONLIB_BUILD_DEFINE_FLAGS:-} \
    $target_flags $link_flags $mode_flags $column_flags -I . -I bindings \
    bindings/_anonlib_x_sequence.mojo -o "$out"
mkdir -p "$outdir"
mv "$out" "$outdir/_anonlib_x_sequence.so"
echo "built $outdir/_anonlib_x_sequence.so"
