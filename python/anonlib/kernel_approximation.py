# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Kernel feature-map approximations, under scikit-learn's module name."""

from .kernel_methods import Nystroem, RBFSampler
from ._expansion_neighbors import AdditiveChi2Sampler, PolynomialCountSketch, SkewedChi2Sampler

__all__ = ["Nystroem", "RBFSampler", "AdditiveChi2Sampler", "PolynomialCountSketch", "SkewedChi2Sampler"]
