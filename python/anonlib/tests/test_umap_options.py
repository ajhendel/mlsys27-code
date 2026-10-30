# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""UMAP option parity (lane/algos-decomp, 2026-09-27): what is accepted and
what is refused by name. Construction validates, so these need no binary.

    .pixi/envs/test/bin/python -m pytest python/anonlib/tests/test_umap_options.py -q
"""
import pytest

from anonlib._umap_impl import UMAP


@pytest.mark.parametrize("kw", [
    dict(metric="manhattan"), dict(metric="cosine"), dict(metric="chebyshev"), dict(metric="sqeuclidean"),
    dict(metric="minkowski", metric_kwds={"p": 3.0}), dict(local_connectivity=2.5), dict(n_components=1),
    dict(n_components=12), dict(init="random"), dict(init="pca"), dict(a=1.5, b=0.8),
])
def test_accepted(kw):
    UMAP(**kw)


@pytest.mark.parametrize("kw, err", [
    (dict(densmap=True), NotImplementedError),
    (dict(output_metric="haversine"), NotImplementedError),
    (dict(metric="hamming"), ValueError),
    (dict(metric=lambda a, b: 0.0), ValueError),
    (dict(metric="manhattan", metric_kwds={"p": 3}), ValueError),
    (dict(a=1.0), ValueError),
    (dict(a=-1.0, b=1.0), ValueError),
    (dict(init="tswspectral"), ValueError),
    (dict(local_connectivity=-1.0), ValueError),
    (dict(n_components=33), ValueError),
])
def test_refused_by_name(kw, err):
    with pytest.raises(err):
        UMAP(**kw)


def test_target_metric_refused_by_name():
    m = UMAP(target_metric="hamming")
    with pytest.raises(NotImplementedError):
        m._target([0, 1, 2], 3)
