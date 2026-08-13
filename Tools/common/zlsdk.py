#!/usr/bin/env python3
"""zlsdk.py — Python reader for Zircon .Zl compressed image libraries.

Supports ZL2 container format used by Zircon (Deflate compressed PNG/RAW image entries).
"""
from __future__ import annotations

import io
import mmap
import os
import struct
import zlib

try:
    import texture2ddecoder
except ImportError:
    texture2ddecoder = None

try:
    import numpy as _np
except ImportError:
    _np = None

try:
    from PIL import Image
except ImportError:
    Image = None


def _decode_bc7(data: bytes, width: int, height: int):
    """BC7 裸块 -> PIL RGBA，复用 img_pipeline 已验证实现。"""
    if texture2ddecoder is None:
        return None
    pixels = texture2ddecoder.decode_bc7(data, width, height)
    # texture2ddecoder 返回 BGRA；PIL 需要 RGBA。
    if _np is not None:
        rgba = _np.frombuffer(pixels, dtype=_np.uint8)
        rgba = rgba.reshape(height, width, 4)[:, :, [2, 1, 0, 3]]
        return Image.frombytes("RGBA", (width, height), rgba.tobytes())
    raw = bytearray(pixels)
    for i in range(0, len(raw), 4):
        raw[i], raw[i + 2] = raw[i + 2], raw[i]
    return Image.frombytes("RGBA", (width, height), bytes(raw))



class Zl2Entry:
    """ZL2 container index entry (matches C# Zl2Entry.Read, 23 bytes).
    Fields: Type, Id, UncompressedSize, CompressedSize, Offset, Compression, Codec."""
    __slots__ = ('type', 'id', 'uncompressed_size', 'compressed_size', 'offset', 'compression', 'codec')

    def __init__(self, etype: int, entry_id: int, uncompressed_size: int, compressed_size: int,
                 offset: int, compression: int, codec: int):
        self.type = etype
        self.id = entry_id
        self.uncompressed_size = uncompressed_size
        self.compressed_size = compressed_size
        self.offset = offset
        self.compression = compression  # 0=None, 1=DeflateFast, 2=DeflateBest
        self.codec = codec               # ZlImageCodec: 0=Dxt1,1=Dxt5,2=Bgra32,3=Bc7,4=Png


class ZlImageHeader:
    __slots__ = ('width', 'height', 'offset_x', 'offset_y', 'position',
                'codec', 'stored_size', 'bc7_size')

    def __init__(self, width: int, height: int, offset_x: int, offset_y: int, position: int,
                 codec: int = 4, stored_size: int = 0, bc7_size: int = 0):
        self.width = width
        self.height = height
        self.offset_x = offset_x
        self.offset_y = offset_y
        self.position = position
        self.codec = codec
        self.stored_size = stored_size
        self.bc7_size = bc7_size



def _rgb565(value: int) -> tuple[int, int, int]:
    return ((value >> 11 & 0x1F) * 255 // 31,
            (value >> 5 & 0x3F) * 255 // 63,
            (value & 0x1F) * 255 // 31)


def _decode_bc1(data: bytes, width: int, height: int, with_alpha: bool = True) -> bytes:
    """BC1 (DXT1) decode. Punchthrough: c0 <= c1 时 index 3 = 透明黑。
    numpy 快路径与纯 Python 循环语义逐字节一致 (含截断式 565->888 与 //3 插值)。"""
    if _np is not None:
        out = _bc1_numpy(data, width, height, with_alpha)
        if out is not None:
            return out
    return _bc1_python(data, width, height, with_alpha)


def _bc_block_grid(data: bytes, width: int, height: int, block_bytes: int):
    """公共 numpy 脚手架: 展开块数据为 (n_blocks, block_bytes) uint8。
    尾部不完整块置零 —— 与 Python 循环 `p + N > len(data): continue` 一致。
    返回 (blocks, bw, bh)；无完整块时返回 None。"""
    bw, bh = (width + 3) // 4, (height + 3) // 4
    n = bw * bh
    if n == 0:
        return None
    nfull = min(n, len(data) // block_bytes)
    if nfull == 0:
        return None
    blocks = _np.zeros((n, block_bytes), dtype=_np.uint8)
    blocks[:nfull] = _np.frombuffer(data, dtype=_np.uint8, count=nfull * block_bytes).reshape(nfull, block_bytes)
    return blocks, bw, bh


def _bc_scatter(px16: "_np.ndarray", bw: int, bh: int, width: int, height: int) -> bytes:
    """(n_blocks, 16, 4) 块序像素 -> 裁剪到 width*height 的行序 RGBA bytes。"""
    grid = px16.reshape(bh, bw, 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape(bh * 4, bw * 4, 4)
    return _np.ascontiguousarray(grid[:height, :width]).tobytes()


def _bc1_core(blocks8: "_np.ndarray", with_alpha: bool) -> "_np.ndarray":
    """(n, 8) BC1 块 -> (n, 16, 4) RGBA (块序)。与 _bc1_python 语义一致。"""
    u16 = blocks8.view(_np.uint16)
    c0 = u16[:, 0].astype(_np.uint32)
    c1 = u16[:, 1].astype(_np.uint32)
    bits = blocks8.view(_np.uint32).reshape(-1, 2)[:, 1].astype(_np.uint32)
    # 565 -> 888 (与 _rgb565 的 (v*255)//31 截断一致)
    a = _np.stack([(c0 >> 11 & 31) * 255 // 31,
                   (c0 >> 5 & 63) * 255 // 63,
                   (c0 & 31) * 255 // 31], axis=1).astype(_np.uint16)
    b = _np.stack([(c1 >> 11 & 31) * 255 // 31,
                   (c1 >> 5 & 63) * 255 // 63,
                   (c1 & 31) * 255 // 31], axis=1).astype(_np.uint16)
    punch = (c0 <= c1) & bool(with_alpha)
    p2 = _np.where(punch[:, None], (a + b) // 2, (2 * a + b) // 3)
    p3 = _np.where(punch[:, None], _np.zeros_like(a), (a + 2 * b) // 3)
    palette = _np.stack([a, b, p2, p3], axis=1).astype(_np.uint8)      # (n, 4, 3)
    idx = (bits[:, None] >> (2 * _np.arange(16, dtype=_np.uint32))) & 3  # (n, 16)
    rgb = palette[_np.arange(len(blocks8))[:, None], idx]                # (n, 16, 3)
    alpha = _np.where(punch[:, None] & (idx == 3), 0, 255).astype(_np.uint8)
    return _np.concatenate([rgb, alpha[:, :, None]], axis=2)             # (n, 16, 4)


def _bc1_numpy(data: bytes, width: int, height: int, with_alpha: bool):
    pre = _bc_block_grid(data, width, height, 8)
    if pre is None:
        return None
    blocks, bw, bh = pre
    return _bc_scatter(_bc1_core(blocks, with_alpha), bw, bh, width, height)


def _bc1_python(data: bytes, width: int, height: int, with_alpha: bool) -> bytes:
    out = bytearray(width * height * 4)
    for by in range((height + 3) // 4):
        for bx in range((width + 3) // 4):
            p = (by * ((width + 3) // 4) + bx) * 8
            if p + 8 > len(data):
                continue
            c0, c1, bits = struct.unpack_from('<HHI', data, p)
            a = _rgb565(c0)
            b = _rgb565(c1)
            palette = [a, b]
            if c0 > c1 or not with_alpha:
                palette += [tuple((2 * a[i] + b[i]) // 3 for i in range(3)),
                            tuple((a[i] + 2 * b[i]) // 3 for i in range(3))]
            else:
                palette += [tuple((a[i] + b[i]) // 2 for i in range(3)), (0, 0, 0)]
            for iy in range(4):
                for ix in range(4):
                    x, y = bx * 4 + ix, by * 4 + iy
                    if x >= width or y >= height:
                        continue
                    index = (bits >> (2 * (iy * 4 + ix))) & 3
                    r, g, b = palette[index]
                    alpha = 0 if with_alpha and c0 <= c1 and index == 3 else 255
                    q = (y * width + x) * 4
                    out[q:q + 4] = bytes((r, g, b, alpha))
    return bytes(out)


def _decode_bc3(data: bytes, width: int, height: int) -> bytes:
    """BC3 (DXT5) decode. alpha 调色板遵循 DXT5 规范 (与 GPU/texture2ddecoder 一致):
    a0 >  a1: [a0, a1, (6a0+a1)/7, (5a0+2a1)/7, (4a0+3a1)/7, (3a0+4a1)/7, (2a0+5a1)/7, (a0+6a1)/7]
    a0 <= a1: [a0, a1, (4a0+3a1)/7, (3a0+4a1)/7, (2a0+5a1)/7, (a0+6a1)/7, 0, 255]
    (旧纯 Python 实现用 //8 除数且把 0/255 放在 3 位索引够不到的第 8/9 位 —— 违反规范, 已修正。)"""
    if _np is not None:
        out = _bc3_numpy(data, width, height)
        if out is not None:
            return out
    return _bc3_python(data, width, height)


def _bc3_alpha_palette(a0: "_np.ndarray", a1: "_np.ndarray") -> "_np.ndarray":
    """(n,) a0/a1 -> (n, 8) uint8, DXT5 规范 alpha 调色板。"""
    a0 = a0.astype(_np.uint16)
    a1 = a1.astype(_np.uint16)
    gt = a0 > a1
    return _np.stack([a0, a1,
                      _np.where(gt, (6 * a0 + a1) // 7, (4 * a0 + 3 * a1) // 7),
                      _np.where(gt, (5 * a0 + 2 * a1) // 7, (3 * a0 + 4 * a1) // 7),
                      _np.where(gt, (4 * a0 + 3 * a1) // 7, (2 * a0 + 5 * a1) // 7),
                      _np.where(gt, (3 * a0 + 4 * a1) // 7, (a0 + 6 * a1) // 7),
                      _np.where(gt, (2 * a0 + 5 * a1) // 7, 0),
                      _np.where(gt, (a0 + 6 * a1) // 7, 255)], axis=1).astype(_np.uint8)


def _bc3_numpy(data: bytes, width: int, height: int):
    pre = _bc_block_grid(data, width, height, 16)
    if pre is None:
        return None
    blocks, bw, bh = pre
    a0 = blocks[:, 0]
    a1 = blocks[:, 1]
    # 48 位 alpha 索引小端 packed (与 int.from_bytes(data[p+2:p+8], 'little') 一致)
    alpha_bits = _np.zeros((len(blocks), 8), dtype=_np.uint8)
    alpha_bits[:, :6] = blocks[:, 2:8]
    alpha_bits_u64 = alpha_bits.view(_np.uint64).reshape(-1)
    pal = _bc3_alpha_palette(a0, a1)                                   # (n, 8)
    aidx = (alpha_bits_u64[:, None] >> (3 * _np.arange(16, dtype=_np.uint64))) & 7
    alpha = pal[_np.arange(len(blocks))[:, None], aidx]                # (n, 16)
    rgb = _bc1_core(blocks[:, 8:16], False)[:, :, :3]                  # (n, 16, 3) 无 punchthrough
    px = _np.concatenate([rgb, alpha[:, :, None]], axis=2)             # (n, 16, 4)
    return _bc_scatter(px, bw, bh, width, height)


def _bc3_alpha_palette_bytes(a0: int, a1: int) -> list[int]:
    """DXT5 规范 alpha 调色板 (标量版, 与 _bc3_alpha_palette 一致)。"""
    if a0 > a1:
        return [a0, a1,
                (6 * a0 + a1) // 7, (5 * a0 + 2 * a1) // 7,
                (4 * a0 + 3 * a1) // 7, (3 * a0 + 4 * a1) // 7,
                (2 * a0 + 5 * a1) // 7, (a0 + 6 * a1) // 7]
    return [a0, a1,
            (4 * a0 + 3 * a1) // 7, (3 * a0 + 4 * a1) // 7,
            (2 * a0 + 5 * a1) // 7, (a0 + 6 * a1) // 7, 0, 255]


def _bc3_python(data: bytes, width: int, height: int) -> bytes:
    out = bytearray(width * height * 4)
    blocks_w = (width + 3) // 4
    for by in range((height + 3) // 4):
        for bx in range(blocks_w):
            p = (by * blocks_w + bx) * 16
            if p + 16 > len(data):
                continue
            a0, a1 = data[p], data[p + 1]
            alpha_bits = int.from_bytes(data[p + 2:p + 8], 'little')
            pal8 = _bc3_alpha_palette_bytes(a0, a1)
            color = _bc1_python(data[p + 8:p + 16], 4, 4, False)
            for iy in range(4):
                for ix in range(4):
                    x, y = bx * 4 + ix, by * 4 + iy
                    if x >= width or y >= height:
                        continue
                    ai = (alpha_bits >> (3 * (iy * 4 + ix))) & 7
                    src = (iy * 4 + ix) * 4
                    q = (y * width + x) * 4
                    out[q:q + 4] = color[src:src + 3] + bytes((pal8[ai],))
    return bytes(out)


def _bgra_to_rgba(data: bytes, width: int, height: int) -> bytes:
    """Convert BGRA32 buffer to RGBA (swap R/B channels)."""
    if _np is not None and len(data) >= width * height * 4:
        px = _np.frombuffer(data, dtype=_np.uint8, count=width * height * 4)
        return px.reshape(height, width, 4)[:, :, [2, 1, 0, 3]].tobytes()
    out = bytearray(len(data))
    for i in range(0, len(data), 4):
        out[i] = data[i + 2]      # R <- B
        out[i + 1] = data[i + 1]  # G
        out[i + 2] = data[i]      # B <- R
        out[i + 3] = data[i + 3]  # A
    return bytes(out)


class ZlLibrary:
    """Python loader for Zircon .Zl libraries."""

    def __init__(self, path: str):
        self.path = path
        self.name = os.path.basename(path)
        # 资源库很大(单库可达数百 MB, 全部约 6.4GB), 使用 mmap 避免启动时
        # 把整个 Data 目录读进内存；访问帧时由内核按需载入页面。
        self._fh = open(path, "rb")
        self.data = mmap.mmap(self._fh.fileno(), 0, access=mmap.ACCESS_READ)

        self.entries: dict[int, Zl2Entry] = {}
        self.headers: dict[int, ZlImageHeader] = {}
        self.count = 0
        self.is_zl2 = False
        self._parse()

    def _parse(self):
        if len(self.data) < 43 or self.data[:3] != b"ZL2":
            self._parse_v1()
            return

        self.is_zl2 = True
        meta_offset = struct.unpack_from("<q", self.data, 19)[0]
        meta_size = struct.unpack_from("<i", self.data, 27)[0]
        index_offset = struct.unpack_from("<q", self.data, 31)[0]
        index_size = struct.unpack_from("<i", self.data, 39)[0]

        # 1. Parse Index Block — C# Zl2Entry.Read: Type(1) Id(i32) UncompressedSize(i32)
        #    CompressedSize(i32) Offset(i64) Compression(byte) Codec(byte) = 23 bytes
        idx_data = self.data[index_offset: index_offset + index_size]
        idx_pos = 0
        entry_count = struct.unpack_from("<i", idx_data, idx_pos)[0]
        idx_pos += 4

        for _ in range(entry_count):
            etype = idx_data[idx_pos]
            eid = struct.unpack_from("<i", idx_data, idx_pos + 1)[0]
            usize = struct.unpack_from("<i", idx_data, idx_pos + 5)[0]
            csize = struct.unpack_from("<i", idx_data, idx_pos + 9)[0]
            off = struct.unpack_from("<q", idx_data, idx_pos + 13)[0]
            comp = idx_data[idx_pos + 21]
            codec = idx_data[idx_pos + 22]
            idx_pos += 23
            self.entries[eid] = Zl2Entry(etype, eid, usize, csize, off, comp, codec)

        # 2. Parse Metadata Block
        meta_data = self.data[meta_offset: meta_offset + meta_size]
        mpos = 0
        version = struct.unpack_from("<i", meta_data, mpos)[0]
        count = struct.unpack_from("<i", meta_data, mpos + 4)[0]
        mpos += 16 # Skip Version, count, AtlasGroupImageCount, AtlasPageSize
        self.version = version
        self.count = count
        for i in range(count):
            present = meta_data[mpos] != 0
            mpos += 1
            if not present:
                continue
            # C# ZlImage.Read: Position(i32) Width(h) Height(h) OffX(h) OffY(h)
            # ShadowType(byte) ShadowW(h) ShadowH(h) ShadowOffX(h) ShadowOffY(h)
            # OverlayW(h) OverlayH(h)  = 25 bytes baseline
            pos = struct.unpack_from("<i", meta_data, mpos)[0]
            w, h, ox, oy = struct.unpack_from("<hhhh", meta_data, mpos + 4)
            mpos += 25
            codec = 4  # default Png for v0/v1; overwritten for v2
            stored_size = 0
            bc7_size = 0
            if version >= 2:
                # AtlasPage(i32) SourceRect(h×4) VisibleBounds(h×4) = 20 bytes
                mpos += 20
                img_codec = meta_data[mpos]
                shadow_codec = meta_data[mpos + 1]
                overlay_codec = meta_data[mpos + 2]
                mpos += 3
                mpos += 3  # RuntimePreferences
                stored_size = struct.unpack_from("<i", meta_data, mpos)[0]
                bc7_size = struct.unpack_from("<i", meta_data, mpos + 4)[0]
                # FallbackDataSize + Shadow×3 + Overlay×3 = 7 more i32
                mpos += 4 + 4 + 4  # StoredImg, Bc7, Fallback
                mpos += 12  # Shadow×3
                mpos += 12  # Overlay×3
                codec = img_codec
            elif version == 1:
                codec = 1  # Dxt5
            else:
                codec = 0  # Dxt1
            self.headers[i] = ZlImageHeader(w, h, ox, oy, pos, codec, stored_size, bc7_size)

    def _parse_v1(self):
        # Legacy ZL container: int32 metadata size, followed by a packed
        # metadata block and raw DXT payloads at each image Position.
        if len(self.data) < 4:
            return
        meta_size = struct.unpack_from('<i', self.data, 0)[0]
        if meta_size <= 4 or 4 + meta_size > len(self.data):
            return
        meta = self.data[4:4 + meta_size]
        value = struct.unpack_from('<i', meta, 0)[0]
        version = (value >> 25) & 0x7F
        count = value & 0x1FFFFFF
        if version == 0:
            count = value
        self.count = max(0, count)
        pos = 4
        for i in range(self.count):
            if pos >= len(meta):
                break
            present = meta[pos] != 0
            pos += 1
            if not present or pos + 25 > len(meta):
                pos += 25 if present else 0
                continue
            image_pos = struct.unpack_from('<i', meta, pos)[0]
            width, height, ox, oy = struct.unpack_from('<hhhh', meta, pos + 4)
            self.headers[i] = ZlImageHeader(width, height, ox, oy, image_pos)
            pos += 25
        self.version = version

    def header(self, index: int) -> dict | None:
        hdr = self.headers.get(index)
        if hdr is None or hdr.width <= 0 or hdr.height <= 0:
            return None
        return {
            "index": index,
            "width": hdr.width,
            "height": hdr.height,
            "offsetX": hdr.offset_x,
            "offsetY": hdr.offset_y,
        }

    def is_blank(self, index: int) -> bool:
        """空白帧判定 (供 wilsdk.is_blank 委托):
        无 header / 宽高<=0 / ZL2 无载荷 entry (position=-1 稀疏帧,
        C# 客户端 TryGetTexture 对这些帧同样取不到纹理)。"""
        hdr = self.headers.get(index)
        if hdr is None or hdr.width <= 0 or hdr.height <= 0:
            return True
        return self.is_zl2 and hdr.position not in self.entries

    def decode(self, index: int) -> "Image.Image | None":
        if Image is None:
            return None
        hdr = self.headers.get(index)
        if hdr is None or hdr.width <= 0 or hdr.height <= 0:
            return None

        if self.is_zl2:
            entry_id = hdr.position
            if entry_id not in self.entries:
                return None
            entry = self.entries[entry_id]
            raw = self.data[entry.offset: entry.offset + entry.compressed_size]
            if entry.compression != 0:
                # C# DeflateStream = raw deflate (no zlib header); use negative wbits
                raw = zlib.decompressobj(-zlib.MAX_WBITS).decompress(raw)
            if not raw:
                return None
            # primary segment = StoredImageDataSize bytes (or whole raw)
            primary_size = hdr.stored_size if hdr.stored_size > 0 else len(raw)
            if primary_size > len(raw):
                primary_size = len(raw)
            segment = raw[:primary_size]
            codec = hdr.codec
            try:
                if codec == 4:  # Png
                    im = Image.open(io.BytesIO(segment))
                    im.load()
                    return im.convert("RGBA")
                if codec == 2:  # Bgra32
                    return Image.frombytes("RGBA", (hdr.width, hdr.height),
                                           _bgra_to_rgba(segment, hdr.width, hdr.height))
                if codec == 0:  # Dxt1
                    return Image.frombytes("RGBA", (hdr.width, hdr.height),
                                           _decode_bc1(segment, hdr.width, hdr.height, True))
                if codec == 1:  # Dxt5
                    return Image.frombytes("RGBA", (hdr.width, hdr.height),
                                           _decode_bc3(segment, hdr.width, hdr.height))
                if codec == 3:  # Bc7 — 复用已验证的 texture2ddecoder
                    return _decode_bc7(segment, hdr.width, hdr.height)
            except Exception:
                return None
            return None
        else:
            block_size = ((hdr.width + 3) // 4) * ((hdr.height + 3) // 4) * (8 if self.version == 0 else 16)
            raw = self.data[hdr.position:hdr.position + block_size]
            try:
                pixels = (_decode_bc1(raw, hdr.width, hdr.height, True)
                          if self.version == 0 else
                          _decode_bc3(raw, hdr.width, hdr.height))
                return Image.frombytes("RGBA", (hdr.width, hdr.height), pixels)
            except Exception:
                return None

    def decode_scaled(self, index: int, scale: int) -> "Image.Image | None":
        """Decode -> RGBA PIL Image at 1/scale resolution, byte-identical to
        decode() + NEAREST resize for dimensions divisible by scale (all
        tiles).

        Legacy BC1 payloads are decoded block-sampled: only the 4x4 blocks
        touched by PIL's NEAREST source grid (out(j) <- in(j*scale +
        scale//2)) are unpacked, so cost drops ~1/scale^2 (1/4 of blocks at
        scale 8).  ZL2/PNG payloads decode 1:1 then resize (PNG is C-speed).
        """
        if Image is None:
            return None
        hdr = self.headers.get(index)
        if hdr is None or hdr.width <= 0 or hdr.height <= 0:
            return None
        w, h = hdr.width, hdr.height
        if scale <= 1:
            return self.decode(index)
        ow, oh = max(1, w // scale), max(1, h // scale)
        cols = [min(w - 1, int((j + 0.5) * w / ow)) for j in range(ow)]
        rows = [min(h - 1, int((r + 0.5) * h / oh)) for r in range(oh)]

        if self.is_zl2:
            im = self.decode(index)
            if im is None:
                return None
            return im.resize((ow, oh), Image.NEAREST)

        # legacy (v0/v1) path
        # BC1 (version 0): block-sampled gather — numpy 向量化;
        # 无 numpy 时回退标量双循环 (语义等价)。
        if _np is not None and scale >= 2:
            jj = _np.arange(ow, dtype=_np.int64)
            rr = _np.arange(oh, dtype=_np.int64)
            cols_np = _np.minimum(w - 1, ((jj + 0.5) * w / ow).astype(_np.int64))
            rows_np = _np.minimum(h - 1, ((rr + 0.5) * h / oh).astype(_np.int64))
            blocks_w = (w + 3) // 4
            block_id = (rows_np // 4)[:, None] * blocks_w + (cols_np // 4)[None, :]
            inner = ((rows_np % 4)[:, None] * 4 + (cols_np % 4)[None, :])
            uniq, inv = _np.unique(block_id, return_inverse=True)
            # 一次 frombuffer 取整帧块区, fancy-index gather (替代逐块循环)
            n_blocks = blocks_w * ((h + 3) // 4)
            frame = _np.frombuffer(
                self.data, dtype=_np.uint8,
                count=min(n_blocks * 8, len(self.data) - hdr.position),
                offset=hdr.position).reshape(-1, 8)
            blocks = _np.zeros((len(uniq), 8), dtype=_np.uint8)
            ok = uniq < len(frame)
            blocks[ok] = frame[uniq[ok]]
            blk_px = _bc1_core(blocks, True)                        # (nb, 16, 4)
            out = blk_px[inv.reshape(block_id.shape), inner]        # (oh, ow, 4)
            return Image.frombuffer("RGBA", (ow, oh),
                                    _np.ascontiguousarray(out).tobytes(),
                                    "raw", "RGBA", 0, 1)
        block_size = ((w + 3) // 4) * ((h + 3) // 4) * 8
        raw = self.data[hdr.position:hdr.position + block_size]
        blocks_w = (w + 3) // 4
        colmap: dict[int, list] = {}
        for j in range(ow):
            sx = cols[j]
            colmap.setdefault(sx // 4, []).append((sx % 4, j))
        rowmap: dict[int, list] = {}
        for i in range(oh):
            sy = rows[i]
            rowmap.setdefault(sy // 4, []).append((sy % 4, i))
        buf = bytearray(ow * oh * 4)
        for by, rowpix in rowmap.items():
            for bx, colpix in colmap.items():
                p = (by * blocks_w + bx) * 8
                if p + 8 > len(raw):
                    continue
                c0, c1, bits = struct.unpack_from("<HHI", raw, p)
                a = _rgb565(c0)
                b = _rgb565(c1)
                palette = [a, b]
                if c0 > c1:
                    palette += [tuple((2 * a[i] + b[i]) // 3 for i in range(3)),
                                tuple((a[i] + 2 * b[i]) // 3 for i in range(3))]
                else:
                    palette += [tuple((a[i] + b[i]) // 2 for i in range(3)), (0, 0, 0)]
                for iy, i in rowpix:
                    for ix, j in colpix:
                        index = (bits >> (2 * (iy * 4 + ix))) & 3
                        r, g, bb = palette[index]
                        alpha = 0 if index == 3 and c0 <= c1 else 255
                        q = (i * ow + j) * 4
                        buf[q:q + 4] = bytes((r, g, bb, alpha))
        return Image.frombuffer("RGBA", (ow, oh), bytes(buf), "raw", "RGBA", 0, 1)
        # BC3 (version 1): block-sampled gather — 仅解码 NEAREST 采样网格命中的
        # 块 (与 v0 路径同思路), numpy 向量化; 无 numpy 时回退全解码+缩放。
        if _np is None or scale < 2:
            im = self.decode(index)
            if im is None:
                return None
            return im.resize((ow, oh), Image.NEAREST)
        jj = _np.arange(ow, dtype=_np.int64)
        rr = _np.arange(oh, dtype=_np.int64)
        cols_np = _np.minimum(w - 1, ((jj + 0.5) * w / ow).astype(_np.int64))
        rows_np = _np.minimum(h - 1, ((rr + 0.5) * h / oh).astype(_np.int64))
        blocks_w = (w + 3) // 4
        block_id = (rows_np // 4)[:, None] * blocks_w + (cols_np // 4)[None, :]
        inner = ((rows_np % 4)[:, None] * 4 + (cols_np % 4)[None, :])
        uniq, inv = _np.unique(block_id, return_inverse=True)
        nb = len(uniq)
        n_blocks = blocks_w * ((h + 3) // 4)
        frame = _np.frombuffer(
            self.data, dtype=_np.uint8,
            count=min(n_blocks * 16, len(self.data) - hdr.position),
            offset=hdr.position).reshape(-1, 16)
        blocks = _np.zeros((nb, 16), dtype=_np.uint8)
        ok = uniq < len(frame)
        blocks[ok] = frame[uniq[ok]]
        a0 = blocks[:, 0]
        a1 = blocks[:, 1]
        abits = _np.zeros((nb, 8), dtype=_np.uint8)
        abits[:, :6] = blocks[:, 2:8]
        abits = abits.view(_np.uint64).reshape(-1)
        pal_a = _bc3_alpha_palette(a0, a1)                          # (nb, 8)
        rgb16 = _bc1_core(blocks[:, 8:16], False)                   # (nb, 16, 4)
        aidx = (abits[:, None] >> (3 * _np.arange(16, dtype=_np.uint64))) & 7
        alpha_px = pal_a[_np.arange(nb)[:, None], aidx]             # (nb, 16)
        blk_px = _np.concatenate(
            [rgb16[:, :, :3], alpha_px[:, :, None]], axis=2)        # (nb, 16, 4)
        out = blk_px[inv.reshape(block_id.shape), inner]            # (oh, ow, 4)
        return Image.frombuffer("RGBA", (ow, oh),
                                _np.ascontiguousarray(out).tobytes(),
                                "raw", "RGBA", 0, 1)
