# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Probability calibration, under scikit-learn's module name."""

from ._expansion_trees import CalibratedClassifierCV

__all__ = ["CalibratedClassifierCV"]
