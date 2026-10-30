#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
# bayesq_probe.sh <dataset>: tools/bayesq_probe.py on the board block (afc_ab.sh's data and venv), in a built FAST tree.
set -u
for b in board-0834 board-0833; do [ -d $HOME/$b/cache/algos-data/rows-full ] && { B=$HOME/$b; break; }; done
ANONLIB_NUMERIC_MODE=fast ANONLIB_BENCH_INSTALLED=0 PYTHONPATH=$PWD/python \
  $B/cache/venv/bin/python tools/bayesq_probe.py $B/cache/algos-data/rows-full "$1" 2>&1 | grep -E '^BQ|Error|error' | head -80
