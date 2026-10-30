#!/bin/bash
# tools/lowbit_units/gate_job.sh -- lane/lowbit-units, step 0: the existing
# low-bit gate (tools/lowbit_mma_leg.sh: check-gemm-lowbit, the forced-flat
# run and the two sabotage arms) in the lane's OWN tree on a shared box.
# Runs from the tree the queue or the steward starts it in; everything it
# writes lands under bench/results/lowbit_units/<box>/gate/ in that tree.
#
#   sh tools/nvidia_central.sh submit lowbit-units /root/anonlib-lowbit-units/tools/lowbit_units/gate_job.sh
set -u
cd "$(dirname "$0")/../.." || exit 9
BOX=${ANONLIB_LOWBIT_BOX:-$(hostname -s)}
export ANONLIB_LOWBIT_LEG_ROOT="$PWD"
# ANONLIB_LOWBIT_RESULTS: the results folder of the lane that runs this
# (tools/lowbit_units/price_job.sh says why).
export ANONLIB_LOWBIT_LEG_OUT="$PWD/${ANONLIB_LOWBIT_RESULTS:-bench/results/lowbit_units}/$BOX/gate"
rm -rf "$ANONLIB_LOWBIT_LEG_OUT"
sh tools/lowbit_mma_leg.sh
rc=$?
cat "$ANONLIB_LOWBIT_LEG_OUT/status.tsv" "$ANONLIB_LOWBIT_LEG_OUT/gate.txt" 2>/dev/null
for f in lowbit lowbit-force-flat; do
    echo "== $f (tail)"; tail -25 "$ANONLIB_LOWBIT_LEG_OUT/$f.log" 2>/dev/null
done
exit $rc
