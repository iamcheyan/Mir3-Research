#!/usr/bin/env python3
"""mapedit.minimap — 游戏小地图库解码（MiniMap.Zl / FMMap/MMap.wil）。"""
from __future__ import annotations
import os
from functools import lru_cache

from wilsdk import WilLibrary
from zlsdk import ZlLibrary

from mapedit.constants import _cache_file

# ---- Game minimap assets (MiniMap.Zl / mmap.wil) ----
# MapInfo.MiniMap (System.db, via Tools/SystemDbProbe --minimap) maps a map
# file stem -> frame index in the MiniMap library.  The library lives next to
# the other map-tile libs in the data dir.
MINIMAP_MAP_FILE = _cache_file("minimap_map.txt")    # 2017 ZL client: {stem -> frame} dump (244 maps)
MINIMAP_EI_FILE = _cache_file("minimap_map_ei.txt")  # EI client: {stem -> libname -> frame} dump (182 maps)
MINIMAP_LIB_NAME = "MiniMap.Zl"             # 2017 ZL client
MINIMAP_EI_LIBS = ("FMMap.wil", "MMap.wil") # EI client: FMMap = full/overland, MMap = dungeon


@lru_cache(maxsize=1)
def _minimap_index():
    """{map stem (no ext) -> MiniMap frame index}, or {} if the dump is absent."""
    try:
        idx = {}
        with open(MINIMAP_MAP_FILE, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line:
                    continue
                parts = line.split("\t")
                if len(parts) == 2:
                    try:
                        idx[parts[0]] = int(parts[1])
                    except ValueError:
                        pass
        return idx
    except FileNotFoundError:
        return {}


@lru_cache(maxsize=1)
def _minimap_index_ei():
    """{map stem -> (lib name, frame index)} for the EI client, or {}.

    Dump produced from the EI server's Envir/MiniMap.txt (see
    Tools/maps/gen_minimap_ei.py): overland maps use FMMap.wil with
    frame = value - 1001, dungeon/field maps use MMap.wil with frame = value.
    """
    try:
        idx = {}
        with open(MINIMAP_EI_FILE, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line:
                    continue
                parts = line.split("\t")
                if len(parts) == 3:
                    try:
                        idx[parts[0]] = (parts[1], int(parts[2]))
                    except ValueError:
                        pass
        return idx
    except FileNotFoundError:
        return {}


class MiniMapSource:
    """Decodes the game's minimap library.

    Supports two client generations, auto-detected from the data dir:
      - 2017 ZL client: MiniMap.Zl (frames via System.db MapInfo.MiniMap,
        dumped by SystemDbProbe --minimap into MINIMAP_MAP_FILE).
      - EI client: FMMap.wil (overland, frame = value - 1001) and MMap.wil
        (dungeon/field, frame = value); index dumped from the EI server's
        Envir/MiniMap.txt into MINIMAP_EI_FILE.

    One instance per data dir; libraries are opened lazily.  ``frame(stem)``
    returns the minimap image for a map, or None when the map has no minimap
    or the libraries are missing.
    """

    def __init__(self, data_dir: str):
        self.data_dir = data_dir
        self._zl_lib = None          # 2017: MiniMap.Zl
        self._ei_libs = {}           # EI: name -> WilLibrary
        self._mode = None            # "zl" | "ei"

    _instances: dict = {}

    @classmethod
    def _for(cls, data_dir: str) -> "MiniMapSource":
        """Per-data-dir singleton: minimap libraries are opened at most once."""
        src = cls._instances.get(data_dir)
        if src is None:
            src = cls._instances[data_dir] = cls(data_dir)
        return src

    def _detect(self):
        if self._mode is not None:
            return self._mode
        if not self.data_dir:
            self._mode = None
            return None
        for root in (self.data_dir, os.path.join(self.data_dir, "Map Data")):
            if os.path.exists(os.path.join(root, MINIMAP_LIB_NAME)):
                self._mode = "zl"
                return self._mode
        for root in (self.data_dir, os.path.join(self.data_dir, "Map Data")):
            if os.path.exists(os.path.join(root, "MMap.wil")):
                self._mode = "ei"
                return self._mode
        self._mode = None
        return None

    def _open(self):
        mode = self._detect()
        if mode == "zl":
            if self._zl_lib is not None:
                return self._zl_lib
            for root in (self.data_dir, os.path.join(self.data_dir, "Map Data")):
                p = os.path.join(root, MINIMAP_LIB_NAME)
                if os.path.exists(p):
                    try:
                        self._zl_lib = ZlLibrary(p)
                        return self._zl_lib
                    except Exception:
                        continue
            return None
        if mode == "ei":
            for name in MINIMAP_EI_LIBS:
                if name in self._ei_libs:
                    continue
                for root in (self.data_dir, os.path.join(self.data_dir, "Map Data")):
                    p = os.path.join(root, name)
                    if os.path.exists(p):
                        try:
                            self._ei_libs[name] = WilLibrary(p)
                        except Exception:
                            pass
                        break
            return self._ei_libs or None
        return None

    def frame(self, stem: str):
        mode = self._detect()
        if mode == "zl":
            lib = self._open()
            if lib is None:
                return None
            fid = _minimap_index().get(stem)
            if fid is None:
                return None
            try:
                return lib.decode(fid)
            except Exception:
                return None
        if mode == "ei":
            entry = _minimap_index_ei().get(stem)
            if entry is None:
                return None
            libname, fid = entry
            lib = self._open().get(libname) if self._open() else None
            if lib is None:
                return None
            try:
                return lib.decode(fid)
            except Exception:
                return None
        return None

