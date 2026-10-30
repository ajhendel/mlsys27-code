# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""arima: cuML `cpp/src/arima/` -- the batched Kalman filter log-likelihood,
prediction/forecast, and the finite-difference gradient. Each file in
`arima/impl/` names its reference file; `arima/checks/` holds the host
oracles, the hashed fixtures, and the checks. DEVIATION 670
(their double is our Float32 on the device) is stated once in
`arima/impl/tsa/arima_common.mojo` and carried by every file here. See
`arima/README.md`.
"""
