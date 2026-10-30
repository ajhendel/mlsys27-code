# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 the authors. Part of anonlib, DOI-WITHHELD
"""Entry point for the radius-neighbours surface checks."""

from neighbors.checks.radius_check import (
    check_radius_neighbors_matches_host,
    check_radius_neighbors_reach_by_sabotage,
    check_radius_neighbors_refuses_short_allocation,
    check_radius_neighbors_squared_arm,
)


def main() raises:
    check_radius_neighbors_matches_host()
    check_radius_neighbors_squared_arm()
    check_radius_neighbors_reach_by_sabotage()
    check_radius_neighbors_refuses_short_allocation()
