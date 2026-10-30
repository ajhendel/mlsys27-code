# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""gemm/host: the host oracle that SHIPS in a CPU host binding
(bindings/_anonlib_*_host.mojo; python/anonlib/host_surface.py names
which), moved out of gemm/checks/ by the host surface manifest lane,
2026-09-14. gemm/checks/gemm_oracle.mojo keeps a re-export under the old
name, so every check and bench that imported it still does."""
