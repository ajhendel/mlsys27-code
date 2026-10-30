#!/bin/sh
# The Istella-S leg of lane trees-hotaisle for runners with no body
# environment (tools/gemm_remote_leg.sh on RunPod AMD, 2026-09-11, when
# tools/pick_box.sh printed runpod-amd). Runs from /root/anonlib. The one
# LightGBM OpenCL attempt belongs to the taxi leg, so this leg skips it; its
# lossguide cell still runs LightGBM on the CPU with the retry params.
ANONLIB_TREES_HA_LEG=istella
ANONLIB_TREES_HA_LGBM_OPENCL=0
export ANONLIB_TREES_HA_LEG ANONLIB_TREES_HA_LGBM_OPENCL
exec sh tools/trees_hotaisle_body.sh
