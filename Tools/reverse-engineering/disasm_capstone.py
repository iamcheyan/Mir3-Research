#!/usr/bin/env python3
"""Disassemble the original EI 3.0 Mir3.exe with Capstone.

This tool replaces the llvm-objdump pipeline used by the older extractors:
GNU objdump on this host rejects the binary's section flags, while Capstone
parses the same PE cleanly. It maps image-relative VAs (0x004xxxxx) to file
offsets through the PE section table.

Usage (repo root):
    python3 Tools/reverse-engineering/disasm_capstone.py 0x00414080 [0x00414C00]
    python3 Tools/reverse-engineering/disasm_capstone.py 0x00414080 0x00414C00 --grep "call"
    python3 Tools/reverse-engineering/disasm_capstone.py --xrefs 0x0047AD88
"""
from __future__ import annotations

import argparse
import re
import struct
import sys
from pathlib import Path

try:
    from capstone import CS_ARCH_X86, CS_MODE_32, Cs, x86
except ImportError:
    sys.exit("capstone is required: /home/tetsuya/mir3-venv/bin/pip install capstone")

DEFAULT_EXE = Path("/tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端/Mir3.exe")


class PeImage:
    """Minimal PE loader: VA -> file offset, section listing, string table."""

    def __init__(self, path: Path):
        self.path = path
        data = path.read_bytes()
        self.data = data
        if data[:2] != b"MZ":
            raise ValueError(f"{path} is not an MZ image")
        e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
        if data[e_lfanew:e_lfanew + 4] != b"PE\0\0":
            raise ValueError(f"{path} has no PE signature at {e_lfanew:#x}")
        self.pe = e_lfanew
        self.machine = struct.unpack_from("<H", data, e_lfanew + 4)[0]
        self.nsections = struct.unpack_from("<H", data, e_lfanew + 6)[0]
        opt_size = struct.unpack_from("<H", data, e_lfanew + 20)[0]
        self.image_base = struct.unpack_from("<I", data, e_lfanew + 24 + 28)[0]
        self.sections = []
        off = e_lfanew + 24 + opt_size
        for _ in range(self.nsections):
            name = data[off:off + 8].rstrip(b"\0").decode("latin1", "replace")
            vsize, vaddr, rsize, raddr = struct.unpack_from("<IIII", data, off + 8)
            self.sections.append({
                "name": name, "vsize": vsize, "vaddr": vaddr,
                "rsize": rsize, "raddr": raddr,
            })
            off += 40

    def va_to_offset(self, va: int) -> int | None:
        for s in self.sections:
            if s["vaddr"] <= va - self.image_base < s["vaddr"] + s["vsize"]:
                return s["raddr"] + (va - self.image_base - s["vaddr"])
        return None

    def read_va(self, va: int, size: int) -> bytes | None:
        off = self.va_to_offset(va)
        if off is None:
            return None
        return self.data[off:off + size]

    def disasm(self, start_va: int, count: int = 512):
        md = Cs(CS_ARCH_X86, CS_MODE_32)
        md.detail = True
        md.syntax = x86.X86_INS_GROUP_JUMP if False else md.syntax  # keep intel default
        code = self.read_va(start_va, count * 15)
        if not code:
            return []
        out = []
        for insn in md.disasm(code, start_va):
            if insn.address >= start_va + count * 15:
                break
            out.append(insn)
        return out


def strip_mnemonics(text: str) -> str:
    """Normalize instruction text: drop operands, keep mnemonic + size hints."""
    m = re.match(r"^\s*([a-z][a-z0-9.]*)", text, re.I)
    return m.group(1).lower() if m else ""


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("start", help="start VA, e.g. 0x00414080")
    ap.add_argument("end", nargs="?", help="end VA (exclusive); default start+0x400")
    ap.add_argument("--exe", default=str(DEFAULT_EXE))
    ap.add_argument("--grep", help="regex filter on full instruction text")
    ap.add_argument("--calls", action="store_true",
                    help="print only call instructions (for call-graph extraction)")
    ap.add_argument("--strings", action="store_true",
                    help="dump printable strings found in the VA range")
    ap.add_argument("--xrefs", help="find all direct call/jmp references to a VA")
    args = ap.parse_args()

    img = PeImage(Path(args.exe))
    if args.xrefs:
        target = int(args.xrefs, 16)
        # scan .text for call/jmp rel32 to target
        text = img.sections[0]
        code = img.data[text["raddr"]:text["raddr"] + text["rsize"]]
        hits = []
        for i in range(len(code) - 5):
            b = code[i]
            if b in (0xE8, 0xE9):  # call rel32 / jmp rel32
                rel = struct.unpack_from("<i", code, i + 1)[0]
                va = img.image_base + text["vaddr"] + i
                dest = (va + 5 + rel) & 0xFFFFFFFF
                if dest == target:
                    hits.append((va, b, rel))
        for va, b, rel in hits:
            print(f"{va:#010x}: {'call' if b == 0xE8 else 'jmp'} {target:#x} (rel {rel:#x})")
        print(f"total={len(hits)}")
        return

    start = int(args.start, 16)
    end = int(args.end, 16) if args.end else start + 0x400
    insns = img.disasm(start, (end - start) // 15 + 16)
    if args.strings:
        raw = img.read_va(start, end - start)
        if raw:
            for m in re.finditer(rb"[\x20-\x7e\x80-\xff]{4,}", raw):
                try:
                    s = m.group().decode("gbk", "replace")
                except Exception:
                    s = m.group().decode("latin1", "replace")
                print(f"{start + m.start():#010x}: {s!r}")
        return
    pat = re.compile(args.grep, re.I) if args.grep else None
    for insn in insns:
        if insn.address >= end:
            break
        text = f"{insn.address:#010x}:  {insn.mnemonic}\t{insn.op_str}"
        if args.calls and not insn.mnemonic.startswith("call"):
            continue
        if pat and not pat.search(text):
            continue
        print(text)


if __name__ == "__main__":
    main()
