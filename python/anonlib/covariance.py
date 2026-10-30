# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Robust covariance estimation and outlier detection, under scikit-learn's module name."""

from ._expansion_decomp import EllipticEnvelope, MinCovDet

__all__ = ["EllipticEnvelope", "MinCovDet"]
