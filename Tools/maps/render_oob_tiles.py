#!/usr/bin/env python3
"""Render 512x512 tiles (z=2) with markers over OOB / never-drawn cells.

Deterministic substitute for vision-based hole confirmation (Finding 317-320):
every cell whose mid/front frame exceeds its library's frame count is drawn as
a magenta square at its world position; ground frame-OOB cells are orange;
ground file=0xFF never-drawn blocks are cyan. Output goes to
docs/research/mir3-map-reconstruction/comparisons/<map>__oob_markers_t<tx>-<ty>.png.

Usage:
  MIR3_EI_ROOT=/path/to/EI python3 Tools/maps/render_oob_tiles.py [--map NAME --tx T --ty T]
  (no args -> built-in job table from survey-round14.json)
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
from PIL import Image, ImageDraw

import mapviewer
from audit_mir3_maps import v_lookup, kr_lib_id, EMPTY_FRAME, NO_OBJECT_FILE

EI = os.environ.get('MIR3_EI_ROOT', '/tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端')
MAPS = os.path.join(EI, 'Map')
DATA = os.path.join(EI, 'Data')
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..', '..', 'docs', 'research',
                                    'mir3-map-reconstruction', 'comparisons'))


def load_map(name):
    data = np.frombuffer(open(os.path.join(MAPS, name), 'rb').read(), dtype=np.uint8)
    w = int(np.frombuffer(data[22:24], '<u2')[0]); h = int(np.frombuffer(data[24:26], '<u2')[0])
    bw, bh = w // 2, h // 2
    cell_off = 28 + bw * bh * 3
    rem = int(data.size) - cell_off
    cb = int(rem / (w * h)) if w and h else 0
    cells = data[cell_off:cell_off + w * h * cb].reshape(w, h, cb)
    return w, h, cells, data[28:cell_off].reshape(bw, bh, 3)


def oob_masks(cells, ground, pool, w, h):
    out = {}
    for label, f_idx, fr_slice in (('mid', 4, slice(5, 7)), ('front', 3, slice(7, 9))):
        file_arr = cells[:, :, f_idx]
        frame_arr = cells[:, :, fr_slice].copy().view('<u2').reshape(w, h)
        q, r, v = v_lookup(file_arr)
        lib_id = kr_lib_id(q, r, v, file_arr)
        skip = ((frame_arr == EMPTY_FRAME) | (file_arr == NO_OBJECT_FILE)
                | (r <= 2) | (v > 69) | (lib_id < 0))
        draw = ~skip
        m = np.zeros((w, h), dtype=bool)
        for lid in np.unique(lib_id[draw]):
            mm = draw & (lib_id == lid)
            lib = pool._get_lib(int(lid))
            cap = lib.count if lib is not None else 0
            fr = frame_arr[mm]
            oob = (fr >= cap) & ~((fr >= 0xFF00) & (fr <= 0xFFFE))
            idx = np.nonzero(mm)
            m[idx[0][oob], idx[1][oob]] = True
        out[label] = m
    # ground region: bw*bh blocks, each (file, frame u16); block (bx,by) covers
    # cells (2bx,2by)-(2bx+1,2by+1).
    g_file = ground[:, :, 0]
    g_frame = ground[:, :, 1:3].copy().view('<u2').reshape(ground.shape[0], ground.shape[1])
    gq, gr, gv = v_lookup(g_file)
    g_draw = (gr <= 2) & (gv <= 69)
    gnd_oob = np.zeros((w, h), dtype=bool)
    for lid in np.unique(g_file[g_draw]):
        lib = pool._get_lib(int(lid))
        cap = lib.count if lib is not None else 0
        m = g_draw & (g_file == lid) & (g_frame >= cap) & (g_frame != 0xFFFF) & (g_frame != 0xFF7F)
        ys, xs = np.nonzero(m)
        gnd_oob[2 * ys, 2 * xs] = True
    out['ground_oob'] = gnd_oob
    out['ground_ff'] = np.zeros((w, h), dtype=bool)
    out['ground_ff'][0::2, 0::2] = (g_file == 0xFF)
    return out


def render_tile_markers(name, tx, ty, out_path, z=2):
    pool = mapviewer.FramePool(DATA)
    mc = mapviewer.MapCache(MAPS)
    w, h, cells, ground = load_map(name)
    masks = oob_masks(cells, ground, pool, w, h)
    img = Image.open(io.BytesIO(mapviewer.render_tile(mc, pool, name, tx, ty, z)))
    d = ImageDraw.Draw(img, 'RGBA')
    tw = 512 * (1 << z)            # world units per tile
    wx0, wy0 = tx * tw, ty * tw
    px = 48 / (1 << z)             # px per cell x
    py = 32 / (1 << z)             # px per cell y
    total = 0
    for label, m in masks.items():
        if label == 'ground_ff':
            color, alpha = (0, 255, 255), 200   # cyan = file 0xFF never-drawn ground
        elif label == 'ground_oob':
            color, alpha = (255, 128, 0), 220   # orange = ground frame OOB
        else:
            color, alpha = (255, 0, 255), (140 if label == 'mid' else 255)
        ys, xs = np.nonzero(m)
        for x, y in zip(xs, ys):
            if wx0 <= x * 48 < wx0 + tw and wy0 <= y * 32 < wy0 + tw:
                sx = (x * 48 - wx0) * 512 / tw
                sy = (y * 32 - wy0) * 512 / tw
                d.rectangle([sx, sy, sx + px - 1, sy + py - 1], fill=color + (alpha,))
                total += 1
    img.save(out_path)
    print(f'{name} tile({tx},{ty}): {total} marked OOB cells -> {out_path}')


def _jobs_default():
    """class-3 / class-8 marker tiles (survey-round14.json authoritative)."""
    return [
        ('3.map', 2, 4), ('3.map', 6, 2),
        ('41.map', 2, 2), ('41.map', 1, 2),
        ('50.map', 2, 1),
        ('D10031.map', 0, 0),
        ('0_000.map', 0, 0),
        ('kt0018.map', 0, 0),
        ('74.map', 7, 4),
        ('D12121.map', 1, 0),
        ('0_003.map', 2, 0),
        ('123.map', 9, 4),
        ('D1401.map', 6, 0),
    ]


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--map'); ap.add_argument('--tx', type=int); ap.add_argument('--ty', type=int)
    ap.add_argument('--out', help='output path override (default comparisons/<map>__oob_markers_t<tx>-<ty>.png)')
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    jobs = [(a.map, a.tx, a.ty)] if a.map else _jobs_default()
    for name, tx, ty in jobs:
        out_path = a.out or os.path.join(OUT, f'{name}__oob_markers_t{tx}-{ty}.png')
        try:
            render_tile_markers(name, tx, ty, out_path)
        except Exception:
            import traceback
            traceback.print_exc()
