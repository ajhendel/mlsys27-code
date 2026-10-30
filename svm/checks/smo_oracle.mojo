# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Re-export. The SMO host oracle SHIPS in the svm CPU host binding
(python/anonlib/host_surface.py names it), so it lives in
`svm/host/smo_oracle.mojo` since the host surface manifest lane, 2026-09-14.
svm/checks/svc_check.mojo keeps resolving through this file, its four
private helpers included; new code imports `svm.host.smo_oracle` directly."""

from svm.host.smo_oracle import (
    ORACLE_ETA_EPS,
    ORACLE_MAX_INNER,
    ORACLE_WS_SIZE,
    OracleResult,
    SMO_ORACLE_HOST_SABOTAGE,
    _block_solve,
    _kernel_cell,
    _row_norm,
    _vec_index,
    dual_objective,
    global_kkt_gap,
    in_lower_g,
    in_upper_g,
    smo_oracle_decision,
    smo_oracle_fit,
    svr_dual_objective,
    svr_gradient_reference,
    svr_kkt_gap,
    svr_tube_bound,
)
