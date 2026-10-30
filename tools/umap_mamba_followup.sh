#!/usr/bin/env bash
# Serial source/API qualification after the native backward certificate.
# No rental or wheel-publication actions. Parent must bound this whole job.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
OUT=${ANONLIB_FOLLOWUP_OUT:?set an artifact directory}
mkdir -p "$OUT"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export MAX_JOBS=4 CMAKE_BUILD_PARALLEL_LEVEL=4
export ANONLIB_NUMERIC_MODE=identical
export PYTHONPATH="$ROOT/python"
rc=0
run() {
    local name=$1
    shift
    "$@" > "$OUT/$name.log" 2>&1
    local status=$?
    printf '%s\t%s\n' "$name" "$status" | tee -a "$OUT/results.tsv"
    [ "$status" = 0 ] || rc=1
    return "$status"
}
: > "$OUT/results.tsv"
run umap-self-neighbors pixi run mojo run -j 2 -I . umap/checks/self_neighbor_check.mojo
run umap-broader pixi run mojo run -D ANONLIB_NUMERIC_IDENTICAL=1 -I . umap/checks/identity_broader_check.mojo
if run build-metrics bash bindings/build_metrics.sh; then
    run umap-api pixi run -e skgpu python python/anonlib/tests/test_umap_surface.py
    run umap-transform-api pixi run -e skgpu python python/anonlib/tests/test_umap_transform.py
    run umap-transform-quality pixi run -e skgpu python tools/umap_transform_quality_check.py --mode identical --profile expanded --device "${ANONLIB_MAMBA_CERT_VENDOR:-remote}" --output "$OUT/transform-quality.json"
    run umap-quality pixi run -e skgpu python tools/umap_quality_check.py --mode identical --device "${ANONLIB_MAMBA_CERT_VENDOR:-remote}" --output "$OUT/quality.json"
fi
run umap-transform-native pixi run mojo run -j 4 -D ANONLIB_NUMERIC_IDENTICAL=1 -I . umap/checks/transform_check.mojo
run umap-sparse-graph pixi run mojo run -j 4 -D ANONLIB_NUMERIC_IDENTICAL=1 -I . umap/checks/sparse_graph_check.mojo
run umap-sparse-fit pixi run mojo run -j 4 -D ANONLIB_NUMERIC_IDENTICAL=1 -I . umap/checks/sparse_estimator_check.mojo
run umap-sparse-fast env ANONLIB_UMAP_SPARSE_FAST_LARGE=1 pixi run mojo run -j 4 -I . umap/checks/sparse_estimator_check.mojo
run knn-dispatch-legacy pixi run mojo run -j 4 -D ANONLIB_NUMERIC_IDENTICAL=1 -I . bench/knn_smallk_dispatch_check.mojo
run knn-dispatch-experimental pixi run mojo run -j 4 -D ANONLIB_NUMERIC_IDENTICAL=1 -D ANONLIB_EXPERIMENTAL_SMALLK_IDENTICAL=1 -I . bench/knn_smallk_dispatch_check.mojo
# Qualify the complete public UMAP fit/transform surface in every numeric mode.
# IDENTICAL was built and checked above; the other builds run one at a time.
for mode in fast; do
    if run "build-metrics-$mode" env ANONLIB_NUMERIC_MODE="$mode" bash bindings/build_metrics.sh; then
        run "umap-api-$mode" env ANONLIB_NUMERIC_MODE="$mode" pixi run -e skgpu python -m unittest discover -s python/anonlib/tests -p 'test_umap*.py'
        run "umap-transform-quality-$mode" env ANONLIB_NUMERIC_MODE="$mode" pixi run -e skgpu python tools/umap_transform_quality_check.py --mode "$mode" --profile expanded --device "${ANONLIB_MAMBA_CERT_VENDOR:-remote}" --output "$OUT/transform-quality-$mode.json"
    fi
done
# The independent corpus generator is shipped; fixture bytes are generated
# on the remote host rather than silently borrowed from an unrelated build.
if run corpus pixi run -e skgpu python mamba/corpus/gen_corpus.py --family all; then
    if run build-mamba bash bindings/build_mamba.sh; then
        run mamba-api pixi run -e skgpu python python/anonlib/tests/test_mamba_surface.py
    fi
fi
# kNN measurement now belongs to the dedicated four-arm layout campaign.
# Spend this serial certification leg on uncovered sequence lengths instead.
run mamba-long-backward env ANONLIB_MAMBA_CERT_PROFILE=long-sequence-v1 \
    ANONLIB_MAMBA_CERT_VENDOR="${ANONLIB_MAMBA_CERT_VENDOR:?}" \
    ANONLIB_MAMBA_CERT_OUT="$OUT/mamba-long-cert" pixi run bash tools/mamba_backward_certify.sh
printf '%s\n' "$rc" > "$OUT/exit_code"
exit "$rc"
