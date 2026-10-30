#!/bin/bash
# The simulation job with the box named, for the shared NVIDIA pod's queue.
export ANONLIB_LOWBIT_BOX=h100
exec bash "$(dirname "$0")/sim_job.sh"
