#!/bin/bash
# tools/py_lm/job.sh [BASE_REV]: lane/py-lm before == after on one NVIDIA box, one job.
#
#  1. builds every binding the LM lanes run (tools/algos_lane_check.py's builder) in
#     this tree, at the LANE sources;
#  2. rebuilds the two GPU bindings the lane changed (_anonlib_transformer,
#     _anonlib_training) at BASE_REV's sources into $OUT/base_py, a copy of the
#     python package at BASE_REV whose other .so files are this tree's (unchanged);
#  3. runs tools/py_lm/witness.py on base and lane, GPU and CPU, with timings;
#  4. compares base == lane per device, and GPU == CPU for the causal cells
#     (informational), then runs the identity lanes the lane touches.
# The tree is restored to the lane sources before step 3 (git apply -R of the
# same patch), so the lane .so files are built from exactly the committed lane.
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
BASE_REV=${1:-0a11b50c7}
OUT=${OUT:-/root/ev-py-lm/run}
mkdir -p "$OUT"
export ANONLIB_BUILD_LOCK_HELD=1 ANONLIB_COMPILE_JOBS=${ANONLIB_COMPILE_JOBS:-6}
PIXI=$(command -v pixi || echo ~/.pixi/bin/pixi)
PY="$PIXI run -e default python -u"
echo "$(date -u +%FT%TZ) $(hostname) lane tree $(git rev-parse --short HEAD) base $BASE_REV"
$PIXI install -e default > "$OUT/pixi.log" 2>&1 || { echo PIXI FAIL; tail -3 "$OUT/pixi.log"; exit 1; }
nvidia-smi --query-gpu=name --format=csv,noheader | head -1

LANES=byte-lm,byte-lm-resident,byte-lm-host-train,samba,samba-untied-dropout-accum,transformer-decode-session,transformer,mamba1-decode-session
build_needed () {
  $PY - "$LANES" "$OUT/build.log" <<'PY'
import sys; sys.path.insert(0, "tools")
import algos_lane_check as a
need = set().union(*a.needed_bindings(sys.argv[1].split(",")).values())
need |= {"_anonlib_transformer", "_anonlib_training", "_anonlib_mamba", "_anonlib_neural_host",
         "_anonlib_transformer_host", "_anonlib_mamba_host", "_anonlib_training_host"}
need = {b for b in need if (a.ROOT / "bindings" / a.script_for(b)).is_file()}
a.ensure_built(sorted(need), sys.argv[2])
print("BUILT", len(need), "bindings")
PY
}

# ---- base: the two changed GPU bindings and the python package at BASE_REV
PATCH="$OUT/to_base.patch"
if git rev-parse -q --verify "$BASE_REV^{commit}" >/dev/null; then
  git diff HEAD "$BASE_REV" -- bindings training python > "$PATCH"
else
  cp tools/py_lm/to_base.patch "$PATCH"   # made on the Mac: git diff HEAD <base> -- bindings training python
fi
if [ ! -s "$PATCH" ]; then echo "NO BASE PATCH"; exit 1; fi
FILES=$(grep -E '^(\+\+\+|---) [ab]/' "$PATCH" | cut -c7- | sort -u)
BEFORE=$(cat $FILES 2>/dev/null | sha256sum)
git apply "$PATCH" || { echo "BASE PATCH DOES NOT APPLY"; exit 1; }
rm -f python/anonlib/identical/_anonlib_transformer.so python/anonlib/identical/_anonlib_training.so
build_needed 2>&1 | tail -4
rm -rf "$OUT/base_py"; mkdir -p "$OUT/base_py"
(cd python && tar --exclude='*.so' --exclude='__pycache__' -cf - anonlib) | tar -xf - -C "$OUT/base_py"
mkdir -p "$OUT/base_so"
cp python/anonlib/identical/_anonlib_transformer.so python/anonlib/identical/_anonlib_training.so "$OUT/base_so/"
git apply -R "$PATCH" || { echo "PATCH REVERSAL FAILED"; exit 1; }
[ "$(cat $FILES 2>/dev/null | sha256sum)" = "$BEFORE" ] || { echo "TREE NOT BACK AT THE LANE"; exit 1; }

# ---- lane
rm -f python/anonlib/identical/_anonlib_transformer.so python/anonlib/identical/_anonlib_training.so
build_needed 2>&1 | tail -4
# every lane .so into the base package, then the two base .so files over them
(cd python/anonlib && find . -name '*.so' -o -name '*.so.*' -o -name '*.stamp.json' -o -name '*.lanecheck-stamp' | while read f; do
   mkdir -p "$OUT/base_py/anonlib/$(dirname "$f")"; cp -p "$f" "$OUT/base_py/anonlib/$f"; done)
[ -d python/anonlib/.libs ] && cp -rp python/anonlib/.libs "$OUT/base_py/anonlib/"
cp "$OUT/base_so/"*.so "$OUT/base_py/anonlib/identical/"
cmp -s "$OUT/base_py/anonlib/identical/_anonlib_training.so" python/anonlib/identical/_anonlib_training.so \
  && echo "WARNING: base and lane training .so are byte-identical"

# ---- witness: base and lane, GPU and CPU
arm () {  # arm <name> <pythonpath> <gpu|cpu>
  local env="PYTHONPATH=$2 ANONLIB_NUMERIC_MODE=identical OMP_NUM_THREADS=1"
  if [ "$3" = cpu ]; then
    env="$env ANONLIB_VENDOR=cpu ANONLIB_HOST_DIR=$2/anonlib/host ANONLIB_FOREST_HOST_BINARY=$2/anonlib/host/_anonlib_forest_host.so ANONLIB_BYTE_LM_HOST_BINARY=$2/anonlib/host/_anonlib_byte_lm_host.so"
  fi
  env $env $PIXI run -e default python -u tools/py_lm/witness.py --device "$3" --out "$OUT/$1.json" --timing > "$OUT/$1.log" 2>&1
  echo "$1: exit $? $(tail -1 "$OUT/$1.log")"
}
arm base-gpu "$OUT/base_py" gpu
arm lane-gpu "$ROOT/python" gpu
arm base-cpu "$OUT/base_py" cpu
arm lane-cpu "$ROOT/python" cpu
echo "== GPU base vs lane"; $PY tools/py_lm/witness.py --compare "$OUT/base-gpu.json" "$OUT/lane-gpu.json"
echo "== CPU base vs lane"; $PY tools/py_lm/witness.py --compare "$OUT/base-cpu.json" "$OUT/lane-cpu.json"
echo "== lane GPU vs lane CPU (causal and bytelm cells)"; $PY tools/py_lm/witness.py --common --compare "$OUT/lane-gpu.json" "$OUT/lane-cpu.json" | tail -3

# ---- the identity lanes the lane touches, GPU == CPU on the lane tree
PIXI=$PIXI sh tools/algos_lane_check.sh "$LANES" --out "$OUT/lanes" 2>&1 | grep -E 'RESULT|CLEAN:|DISAGREE|REFUSED' | tail -20
echo "JOB END $(date -u +%FT%TZ)"
