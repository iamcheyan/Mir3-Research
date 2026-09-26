#!/usr/bin/env python3
"""WEMADE 加密的 Mir3 文本解密（EDCode.Decrypt 的 Python 移植）。

**背景**：`Envir3/QuestDiary/NQ_BASE/MonQuest/` 下有 3 个 `.txt`
（`Nm_Chiken`/`Nm_Cow`/`Nm_OmaJunsa`）无法用 GB18030/cp949 解码，
此前在 `config.md` §7 登记为「未破译的私有编码」。

**本轮已破译**：它们是 **WEMADE 加密**（`EDCode.pas:465-522` 的 `Decrypt`）。
文件头 8 字节 = 种子 XOR 长度 + 校验和，正文经 4 轮递增 CRC XOR。

算法（逐字对应 `Source/Common/EDCode.pas:465-522`）：

    CrypToSeed = F0 39 AB 8E, CrypToSeedLong = 0x9FDE1A93

    ProcLen  = big-endian( seed[i] ^ data[i] for i in 0..3 )
               （实测是大端；源码 MakeLong/MakeWord 嵌套写法易误判为小端）
    校验和   = sum((data[8+i] + 1) * i) ^ CrypToSeedLong   （与 data[4..7] 比对）
    解密     = for j in 0..3:
                  crc = data[3-j]
                  for i in 0..ProcLen-1:
                      data[8+i] ^= crc & 0xFF
                      crc += 1

**重要**：实测这 3 个文件的**校验和不匹配**（`data[4..7]` 的值与源码公式
算出的不一致），但**直接做 4 轮 XOR 仍能正确解密**。
即校验和字段可能被另一种方式写坏/加密，而正文变换是标准算法。
→ 本工具**默认跳过校验和验证**，只做 XOR（`--strict` 可强制校验）。

用法:
  wemade_decrypt.py <file>            # 解密并打印
  wemade_decrypt.py <file> --out X    # 解密并写文件
  wemade_decrypt.py --scan <dir>      # 扫描目录，报告哪些文件是加密的
  wemade_decrypt.py <file> --strict   # 强制校验和验证
"""
from __future__ import annotations

import argparse
import os
import struct
import sys

SEED = bytes([0xF0, 0x39, 0xAB, 0x8E])
SEED_LONG = 0x9FDE1A93


def proclen_of(data: bytes) -> int:
    """ProcLen = 大端解释的 (seed XOR data[:4])。"""
    x = bytes(SEED[i] ^ data[i] for i in range(4))
    return int.from_bytes(x, "big")


def calc_checksum(data: bytes, proclen: int) -> int:
    s = 0
    for i in range(proclen):
        s = (s + (data[8 + i] + 1) * i) & 0xFFFFFFFF
    return s ^ SEED_LONG


def decrypt(data: bytes, strict: bool = False) -> tuple[bytes | None, str]:
    """返回 (明文, 说明)。明文为 None 表示失败。"""
    if len(data) < 8:
        return None, "文件小于 8 字节"
    proclen = proclen_of(data)
    if proclen <= 0 or proclen > len(data) - 8:
        return None, f"ProcLen={proclen} 越界（文件 {len(data)} 字节）"
    stored = struct.unpack_from("<I", data, 4)[0]
    calc = calc_checksum(data, proclen)
    note = ""
    if calc != stored:
        note = f"校验和不匹配（算出 0x{calc:08X}，存储 0x{stored:08X}）"
        if strict:
            return None, note
        note += "，仍按 4 轮 XOR 解密"

    buf = bytearray(data[8:8 + proclen])
    for j in range(4):
        crc = data[3 - j]
        for i in range(proclen):
            buf[i] ^= crc & 0xFF
            crc = (crc + 1) & 0xFFFFFFFF
    return bytes(buf), note


def decode_text(raw: bytes) -> tuple[str | None, str]:
    for enc in ("gb18030", "cp949", "utf-8"):
        try:
            return raw.decode(enc), enc
        except UnicodeDecodeError:
            continue
    return None, ""


def looks_encrypted(data: bytes) -> bool:
    """WEMADE 加密文件的判定：头 4 字节 seed XOR 出的 ProcLen == 文件大小-8。"""
    if len(data) < 8:
        return False
    return proclen_of(data) == len(data) - 8


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--out")
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--scan", action="store_true", help="path 视为目录，扫描加密文件")
    args = ap.parse_args()

    if args.scan:
        n = enc = 0
        for root, dirs, files in os.walk(args.path):
            dirs[:] = [d for d in dirs if d not in (".svn", "__history")]
            for fn in sorted(files):
                p = os.path.join(root, fn)
                try:
                    d = open(p, "rb").read()
                except OSError:
                    continue
                n += 1
                if looks_encrypted(d):
                    enc += 1
                    rel = os.path.relpath(p, args.path)
                    raw, note = decrypt(d)
                    txt, e = decode_text(raw) if raw else (None, "")
                    print(f"{'✅' if txt else '❌'} {rel}  ({len(d)}B)"
                          + (f"  [{e}]" if txt else "  解密失败"))
                    if note:
                        print(f"     {note}")
        print(f"\n扫描 {n} 个文件，识别出 {enc} 个 WEMADE 加密文件")
        return 0

    data = open(args.path, "rb").read()
    if not looks_encrypted(data):
        print(f"[WARN] {args.path} 的头 4 字节不像 WEMADE 加密"
              f"（ProcLen={proclen_of(data)}，文件 {len(data)} 字节）",
              file=sys.stderr)
    raw, note = decrypt(data, args.strict)
    if raw is None:
        print(f"[FAIL] {note}", file=sys.stderr)
        return 1
    if note:
        print(f"[note] {note}", file=sys.stderr)
    txt, enc = decode_text(raw)
    if txt is None:
        print(f"[WARN] 解密出 {len(raw)} 字节但无法按 gb18030/cp949/utf-8 解码",
              file=sys.stderr)
        if args.out:
            open(args.out, "wb").write(raw)
        return 1
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(txt)
        print(f"已写 {args.out}（{len(txt)} 字符，编码 {enc}）")
    else:
        sys.stdout.write(txt)
    return 0


if __name__ == "__main__":
    sys.exit(main())
