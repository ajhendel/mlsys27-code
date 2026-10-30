#!/bin/sh
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/build_defines.sh"  # ANONLIB_BUILD_DEFINES -> $ANONLIB_BUILD_DEFINE_FLAGS (compile line)
# Root-only guarded build. No smoke/model/test launch.
# Invoke through the corresponding NVIDIA/AMD/macOS serial guard.
# ANONLIB_NUMERIC_MODE=identical (default) or fast; Linux needs one GPU target.
# ANONLIB_BYTE_LM_OUTDIR overrides the output directory (default
# python/anonlib/identical for identical, python/anonlib for fast).
# ANONLIB_SKIP_BUILD_GATE=1 is accepted: this script never runs, imports or
# smokes the binding, so there is no gate to skip; it is honored for callers
# (tools/afn_ab.sh) that set it on every binding build.
set -eu
MACOS_FLOOR="11.0"
byte_lm_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$byte_lm_root"
# FAST AND IDENTICAL (afn-lm, 2026-10-03), the same shape as
# build_transformer.sh: identical compiles with -D ANONLIB_NUMERIC_IDENTICAL=1
# and lands under python/anonlib/identical/; fast compiles with no mode
# define (checks/numerics.mojo then resolves NUMERIC_FAST), lands flat in
# python/anonlib/, and promises quality, never bits.
case "${ANONLIB_NUMERIC_MODE:-identical}" in
    identical) byte_lm_mode_define="-D ANONLIB_NUMERIC_IDENTICAL=1"; byte_lm_default_outdir=python/anonlib/identical ;;
    fast) byte_lm_mode_define=""; byte_lm_default_outdir=python/anonlib ;;
    *) echo "byte LM supports ANONLIB_NUMERIC_MODE=identical (default) or fast (got '${ANONLIB_NUMERIC_MODE}')" >&2; exit 2 ;;
esac
byte_lm_system=$(uname -s)
if [ "$byte_lm_system" = Darwin ]; then
    [ "$(uname -m)" = arm64 ] || { echo 'byte LM: Metal requires Apple silicon' >&2; exit 2; }
    [ -z "${ANONLIB_GPU_ARCHS:-}" ] || { echo 'byte LM: Metal build requires ANONLIB_GPU_ARCHS unset' >&2; exit 2; }
    case "${ANONLIB_TARGET_COLUMN:-apple}" in
        apple) ;;
        *) echo 'byte LM: Darwin requires the apple target column' >&2; exit 2 ;;
    esac
    # Existing training/Transformer build convention: either an exported
    # deployment target or --target-accelerator suppresses Metal AOT kernels.
    unset MACOSX_DEPLOYMENT_TARGET
    byte_lm_sdk=$(xcrun --sdk macosx --show-sdk-version)
    set -- --target-cpu apple-m1 -D ANONLIB_COLUMN_APPLE \
        -Xlinker -platform_version -Xlinker macos -Xlinker "$MACOS_FLOOR" -Xlinker "$byte_lm_sdk"
elif [ "$byte_lm_system" = Linux ]; then
case "${ANONLIB_GPU_ARCHS:-}" in
    sm_[0-9]*|gfx[0-9]*) ;;
    *) echo 'byte LM: one explicit sm_NN or gfxNNN target required' >&2; exit 2 ;;
esac
case "$ANONLIB_GPU_ARCHS" in
    *[!A-Za-z0-9_]*) echo 'byte LM: invalid/multiple GPU architectures' >&2; exit 2 ;;
esac
# Fixed compiler concurrency; this script never starts a second worker/build.
set -- --target-accelerator "$ANONLIB_GPU_ARCHS"
case "$(uname -m)" in
    x86_64) set -- "$@" --target-cpu ${ANONLIB_LINUX_CPU:-x86-64-v3} ;;
    aarch64) ;;
    *) echo 'byte LM: unsupported Linux host architecture' >&2; exit 2 ;;
esac
case "${ANONLIB_TARGET_COLUMN:-}" in
    '') ;;
    nvidia) set -- "$@" -D ANONLIB_COLUMN_NVIDIA ;;
    amd) set -- "$@" -D ANONLIB_COLUMN_AMD ;;
    amd_rdna) set -- "$@" -D ANONLIB_COLUMN_AMD_RDNA ;;
    *) echo 'byte LM: unsupported target column' >&2; exit 2 ;;
esac
else
    echo 'byte LM: requires Linux CUDA/HIP or Darwin Metal' >&2
    exit 2
fi
byte_lm_outdir=${ANONLIB_BYTE_LM_OUTDIR:-$byte_lm_default_outdir}
mkdir -p "$byte_lm_outdir"
byte_lm_destination="$byte_lm_outdir/_anonlib_byte_lm.so"
# Refuse prior files, including dangling symlinks. Publish via hard link so a
# path created during compilation cannot be overwritten by a rename race.
if [ -e "$byte_lm_destination" ] || [ -L "$byte_lm_destination" ]; then
    echo 'byte LM: output already exists; choose a fresh output directory' >&2
    exit 2
fi
byte_lm_tmpdir=$(mktemp -d "$byte_lm_outdir/.byte-lm-build.XXXXXX")
trap 'rm -rf "$byte_lm_tmpdir"' EXIT HUP INT TERM
case "${ANONLIB_ATTENTION_MEMORY_PROFILE:-estash}" in
    estash) ;;
    recompute) ANONLIB_BUILD_EXTRA_DEFINES="${ANONLIB_BUILD_EXTRA_DEFINES:-} -D ANONLIB_IDN_ATTN_STASH=1" ;;
    packed) ANONLIB_BUILD_EXTRA_DEFINES="${ANONLIB_BUILD_EXTRA_DEFINES:-} -D ANONLIB_IDN_ATTN_STASH=2" ;;
    alias-y) ANONLIB_BUILD_EXTRA_DEFINES="${ANONLIB_BUILD_EXTRA_DEFINES:-} -D ANONLIB_IDN_ATTN_STASH=3" ;;
    *) echo 'ANONLIB_ATTENTION_MEMORY_PROFILE must be estash, packed, alias-y, or recompute' >&2; exit 2 ;;
esac
# ANONLIB_BUILD_EXTRA_DEFINES (optional, empty by default): extra flags
# appended verbatim, word-split, for trial builds (for example
# -D ANONLIB_BYTE_LM_FAULT_INJECT=1 for the session gate's native faults),
# the same hook bindings/build.sh carries. Production builds leave it empty.
# Compiler concurrency: two workers by default, as before; a shared box
# sets ANONLIB_COMPILE_JOBS=1. `mojo build` refuses a repeated -j, so
# the value has to be substituted here rather than appended.
pixi run mojo build -j "${ANONLIB_COMPILE_JOBS:-2}" --emit shared-lib ${ANONLIB_MOJO_BUILD_FLAGS:-} ${ANONLIB_BUILD_DEFINE_FLAGS:-} "$@" ${ANONLIB_BUILD_EXTRA_DEFINES:-} \
    $byte_lm_mode_define -I . -I bindings \
    bindings/_anonlib_byte_lm.mojo -o "$byte_lm_tmpdir/_anonlib_byte_lm.so"
ln "$byte_lm_tmpdir/_anonlib_byte_lm.so" "$byte_lm_destination"
echo "built $byte_lm_destination; numeric_mode=${ANONLIB_NUMERIC_MODE:-identical}; attention_memory_profile=${ANONLIB_ATTENTION_MEMORY_PROFILE:-estash}; root must read byte_lm_numeric_mode/vendor/profile and retain guard exit evidence"
