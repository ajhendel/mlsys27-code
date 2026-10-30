# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""metrics: cuML `cpp/src/metrics/` and the RAFT `raft/stats/` headers they call.

`metrics/impl/` is organized by cuML's thin wrapper files;
`metrics/impl/stats/` cites the RAFT implementations; `metrics/checks/`
is what the references never needed (the pinned reductions, the oracles, the checks).
See `metrics/README.md`.
"""
