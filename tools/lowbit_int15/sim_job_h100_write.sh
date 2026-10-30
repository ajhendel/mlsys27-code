#!/bin/bash
# The first simulation job on the shared NVIDIA pod: the export WRITES the
# vectors that are then committed (a queue job takes one script path and no
# arguments).
export ANONLIB_LOWBIT_BOX=h100
export ANONLIB_INT15_SIM_WRITE=1
exec bash "$(dirname "$0")/sim_job.sh"
