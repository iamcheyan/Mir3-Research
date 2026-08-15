#!/usr/bin/env python3
"""mapedit.frames — WIL/ZL 图库解析与帧缓存（FramePool）。"""
from __future__ import annotations
import os
import threading
from collections import OrderedDict

try:
    from PIL import Image
except ImportError:
    Image = None

from wilsdk import WilLibrary
from zlsdk import ZlLibrary

from mapedit.constants import CACHE_FRAMES_BYTES, KR_ORDER

# ------------------------------------------------------------------ WIL pool

def _find_library_path(data_dir: str, lib_name: str) -> str | None:
    """Find a library in Data, Data/Map Data, or a terrain subdirectory."""
    parts = lib_name.split("_", 1)
    if len(parts) == 2 and parts[0] in {"wood", "sand", "snow", "forest"}:
        folder, filename = parts[0].title(), parts[1]
    else:
        folder, filename = None, lib_name
    filename_candidates = [filename + ".Zl", filename + ".zl", filename + ".wil"]
    roots = [data_dir, os.path.join(data_dir, "Map Data")]
    for root in roots:
        candidates = []
        if folder:
            candidates.append(os.path.join(root, folder))
        candidates.append(root)
        for directory in candidates:
            if not os.path.isdir(directory):
                continue
            for entry in os.listdir(directory):
                if entry.lower() in {name.lower() for name in filename_candidates}:
                    return os.path.join(directory, entry)
    return None


class FramePool:
    """Map library IDs to either legacy WIL or current Zircon ZL libraries."""

    def __init__(self, data_dir: str):
        self.libs: dict[str, WilLibrary | ZlLibrary | None] = {}
        self.lib_paths: dict[str, str] = {}  # lib_name -> resolved file path
        self.data_dir = data_dir
        self._lock = threading.RLock()
        self._frames: OrderedDict = OrderedDict()
        self._frame_bytes = 0

    def _get_lib(self, lib_id: int) -> WilLibrary | ZlLibrary | None:
        lib_name = KR_ORDER.get(lib_id)
        if not lib_name:
            return None
        with self._lock:
            if lib_name not in self.libs:
                path = _find_library_path(self.data_dir, lib_name)
                if path is None:
                    self.libs[lib_name] = None
                elif path.lower().endswith(".zl"):
                    self.libs[lib_name] = ZlLibrary(path)
                    self.lib_paths[lib_name] = path
                else:
                    self.libs[lib_name] = WilLibrary(path)
                    self.lib_paths[lib_name] = path
            return self.libs[lib_name]

    def decode(self, lib_id: int, frame: int, scale: int = 1):
        """Returns (PIL.Image at 1/scale resolution, offsetX, offsetY) or None.

        scale > 1 decodes WIL frames natively at 1/scale (no full-res pass);
        ZL frames are decoded at 1:1 then NEAREST-downscaled (PNG decode is
        C-speed so the win there is cache memory).  Byte-budget LRU: the same
        frame is never re-decoded while its tile is on screen."""
        lib = self._get_lib(lib_id)
        if lib is None or frame < 0 or frame >= lib.count:
            return None
        try:
            hdr = lib.header(frame)
        except Exception:
            return None
        if hdr is None or hdr["width"] <= 0 or hdr["height"] <= 0:
            return None
        key = (lib_id, frame, scale)
        with self._lock:
            img = self._frames.get(key)
            if img is not None:
                self._frames.move_to_end(key)
        if img is None:
            try:
                if scale > 1 and hasattr(lib, "decode_scaled"):
                    im = lib.decode_scaled(frame, scale)
                else:
                    im = lib.decode(frame)
                    if im is not None and scale > 1:
                        im = im.resize((max(1, im.width // scale),
                                        max(1, im.height // scale)), Image.NEAREST)
            except Exception:
                return None
            if im is None:
                return None
            img = (im, hdr["offsetX"], hdr["offsetY"])
            with self._lock:
                self._frames[key] = img
                self._frames.move_to_end(key)
                budget = im.width * im.height * 4 + 64
                self._frame_bytes += budget
                while self._frame_bytes > CACHE_FRAMES_BYTES and len(self._frames) > 1:
                    _, evicted = self._frames.popitem(last=False)
                    self._frame_bytes -= evicted[0].width * evicted[0].height * 4 + 64
        return img


