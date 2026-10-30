# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Python-side gates for the `anonlib` package.

NOT SHIPPED IN THE WHEEL, AND THAT IS A CONSEQUENCE RATHER THAN A CHOICE.
`python/pyproject.toml` lists `packages = ["anonlib"]` explicitly, with the
stated reason that a new subpackage should be a deliberate edit and not a
silent addition to a published artifact. So this package exists in the
checkout and not in the wheel, and everything under it is run from the source
tree with `python/` on the path.

There is no test runner in this repository. `pixi.toml` installs no pytest and
nothing under `tools/` invokes one, so every module here is a plain program
with a `main()` that returns an exit status, runnable either way:

    cd python && python3 -m anonlib.tests.test_linalg_identity
    python3 python/anonlib/tests/test_linalg_identity.py

Adding a dependency to run one gate would make the gate harder to run than the
thing it gates, which is how gates stop being run.
"""
