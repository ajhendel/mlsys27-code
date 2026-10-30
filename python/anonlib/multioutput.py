# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Multi-output wrappers, under scikit-learn's module name."""

from ._expansion_trees import MultiOutputClassifier, MultiOutputRegressor

__all__ = ["MultiOutputClassifier", "MultiOutputRegressor"]
