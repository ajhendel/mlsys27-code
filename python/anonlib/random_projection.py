# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Random projections, under scikit-learn's module name."""

from ._expansion_decomp import GaussianRandomProjection, SparseRandomProjection

__all__ = ["GaussianRandomProjection", "SparseRandomProjection"]
