#!/bin/sh
# tools/linalg_python_gate.sh -- the Python linalg identity gate, the way it
# is meant to be run (2026-09-13). `python/anonlib/tests/test_linalg_identity.py`
# FAILS, by design, when no oracle card is supplied ("a silently skipped
# identity test is worse than no test"), and the card is emitted by
# tools/gemm_card.sh oracle from the NORMATIVE host oracle, which builds the
# GEMM sources. This script does the three steps in order so nobody rediscovers
# the card:
#
#   1. build the IDENTICAL linalg extension (the only tier linalg ships,
#      DEVIATION 2490: the FAST half of the old recipe is retired)
#   2. emit the oracle card into bench/results/gemm_card/<stamp>/oracle.card
#   3. run the gate under IDENTICAL with ANONLIB_GEMM_CARD pointing at it
#
#   pixi run check-linalg-python
#   ANONLIB_GEMM_CARD=<existing card> sh tools/linalg_python_gate.sh   # skips 2
set -eu
cd "$(dirname "$0")/.."
ANONLIB_NUMERIC_MODE=identical bash bindings/build_linalg.sh
if [ -z "${ANONLIB_GEMM_CARD:-}" ]; then
    STAMP=$(date +%Y-%m-%d_%H%M%S)
    OUT="bench/results/gemm_card/$STAMP"
    mkdir -p "$OUT"
    sh tools/gemm_card.sh oracle "$OUT/oracle.card"
    ANONLIB_GEMM_CARD="$PWD/$OUT/oracle.card"
    export ANONLIB_GEMM_CARD
fi
echo "== linalg python gate: ANONLIB_GEMM_CARD=$ANONLIB_GEMM_CARD"
cd python && ANONLIB_NUMERIC_MODE=identical python3 -m anonlib.tests.test_linalg_identity
