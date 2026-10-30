# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Semi-supervised label propagation, under scikit-learn's module name."""

from ._expansion_neighbors import LabelPropagation, LabelSpreading

__all__ = ["LabelPropagation", "LabelSpreading"]
