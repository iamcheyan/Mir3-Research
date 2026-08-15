#!/usr/bin/env python3
"""mapedit.geom — 布局/世界像素几何（rect/iso 投影、缩放梯子）。"""
from __future__ import annotations
from mapedit.constants import (FIT_FULL_DIM, LAYOUT_ISO, LAYOUT_RECT,
                               MAX_FULL_DIM)

# ------------------------------------------------------------------ geometry

def world_bounds(w: int, h: int, layout: str = LAYOUT_RECT) -> tuple[int, int]:
    """Full assembled map size in world pixels."""
    if layout == LAYOUT_ISO:
        return (w + h + 3) * 24, (w + h + 2) * 16
    return w * 48, h * 32


def cell_anchor(x: int, y: int, h: int, layout: str = LAYOUT_RECT) -> tuple[int, int]:
    """World-pixel position of cell (x,y): its top-left corner (rect,
    matching Mir3.exe's (x-view.x)*48 / (y-view.y)*32) or its centre (iso)."""
    if layout == LAYOUT_ISO:
        return (x - y) * 24 + h * 24 + 24, (x + y) * 16 + 16
    return x * 48, y * 32


def map_ladder(w: int, h: int, layout: str = LAYOUT_RECT) -> list[int]:
    """Full-map static zoom ladder: [deepest, ..., fit] as zoom levels
    (0 = 1:1).  Deepest keeps the whole map within MAX_FULL_DIM px on its
    longest side (a single image is feasible); fit is the default overview
    (~FIT_FULL_DIM px).  A full 1:1 image of e.g. 00.map (1360x1500 cells,
    68k x 46k world px) is physically impossible, hence the cap."""
    max_dim = max(world_bounds(w, h, layout))
    deep_z = 0
    while (max_dim >> deep_z) > MAX_FULL_DIM:
        deep_z += 1
    fit_z = deep_z
    while (max_dim >> (fit_z + 1)) >= FIT_FULL_DIM:
        fit_z += 1
    return list(range(deep_z, fit_z + 1))


