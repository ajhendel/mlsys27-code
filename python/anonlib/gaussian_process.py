# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Gaussian process regression and classification and their kernels, under scikit-learn's module name."""

from ._gp_impl import GaussianProcessRegressor, ConstantKernel, Matern, RBF, WhiteKernel
from ._gpc_impl import GaussianProcessClassifier

__all__ = ["GaussianProcessRegressor", "ConstantKernel", "Matern", "RBF", "WhiteKernel", "GaussianProcessClassifier"]
