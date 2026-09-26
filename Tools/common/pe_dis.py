#!/usr/bin/env python3
"""PE 反汇编小工具（用于 EI 原版客户端 Mir3.exe 的静态分析）。

背景（2026-09-27 定位）：
  原版客户端在 **82 机**上：/home/tetsuya/mir2ei/Mir3.exe（512 KB，未加壳）。
  ImageBase=0x00400000，.text VA=0x401000 VSize=0x74AE2（0x401000-0x475AE2 是代码）。
  .data VA=0x47A000 VSize=0x49EFD4 但 RawSize 只有 0x5000 —— 文件小是因为
  .data 大部分是**未初始化**数据，不是加壳。
  判据：证据里的地址（如商店 ctor 0x44D310）必须落在 .text 内；EI传奇.exe 的
  镜像只到 0x417000，覆盖不到 0x44D310，**不是**分析目标。

依赖：capstone（82 机已有 5.0.7；本机没有）。pefile 未装，故这里手写 PE 头解析。

用法：
  # 在 82 机上（需先把本文件 scp 过去，或直接 python3 内联）
  python3 pe_dis.py /home/tetsuya/mir2ei/Mir3.exe 0x44D310 40

  作为库：
    from pe_dis import PE
    p = PE("Mir3.exe")
    p.read(va, n)          # 按 VA 读原始字节（自动跨节）
    p.dis(va, n, limit=60) # 按 VA 反汇编，返回 "0xADDR  mnemonic  op_str" 列表
    p.find_xref(0x7DA060)  # 扫描 .text 里对某绝对地址的引用（push/mov 立即数）
"""
import struct
import sys

from capstone import Cs, CS_ARCH_X86, CS_MODE_32


class PE:
    def __init__(self, path):
        self.d = open(path, "rb").read()
        if self.d[:2] != b"MZ":
            raise ValueError("非 PE 文件")
        e = struct.unpack_from("<I", self.d, 0x3C)[0]
        if self.d[e:e + 4] != b"PE\0\0":
            raise ValueError("无 PE 签名")
        nsec = struct.unpack_from("<H", self.d, e + 6)[0]
        opt = e + 24
        self.base = struct.unpack_from("<I", self.d, opt + 28)[0]
        self.image_size = struct.unpack_from("<I", self.d, opt + 56)[0]
        self.secs = []
        off = opt + struct.unpack_from("<H", self.d, e + 20)[0]
        for i in range(nsec):
            s = self.d[off + i * 40:off + i * 40 + 40]
            nm = s[:8].rstrip(b"\0").decode("latin1")
            vs, va, rs, ra = struct.unpack_from("<IIII", s, 8)
            self.secs.append((nm, self.base + va, vs, ra, rs))

    def section_of(self, va):
        for nm, sva, vs, ra, rs in self.secs:
            if sva <= va < sva + max(vs, rs):
                return nm
        return None

    def read(self, va, n):
        """按 VA 读 n 字节（不跨节拼接，超出即截断）。"""
        for nm, sva, vs, ra, rs in self.secs:
            if sva <= va < sva + max(vs, rs):
                o = ra + (va - sva)
                return self.d[o:o + n]
        return b""

    def dis(self, va, n, limit=60):
        code = self.read(va, n)
        md = Cs(CS_ARCH_X86, CS_MODE_32)
        out = []
        for ins in md.disasm(code, va):
            out.append("0x%08X  %-10s %s" % (ins.address, ins.mnemonic, ins.op_str))
            if len(out) >= limit:
                break
        return out

    def find_xref(self, target, limit=40):
        """在 .text 里找对某绝对地址的引用（push imm32 / mov reg, imm32 / cmp）。

        只匹配「立即数 == target」的指令，够用来定位全局量的读取点。
        """
        md = Cs(CS_ARCH_X86, CS_MODE_32)
        hits = []
        for nm, sva, vs, ra, rs in self.secs:
            if nm != ".text":
                continue
            code = self.d[ra:ra + min(vs, rs)]
            for ins in md.disasm(code, sva):
                for op in ins.operands:
                    if op.type == 2 and op.imm == target:  # X86_OP_IMM
                        hits.append("0x%08X  %-10s %s" % (ins.address, ins.mnemonic, ins.op_str))
                        break
                if len(hits) >= limit:
                    return hits
        return hits


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    path, va = sys.argv[1], int(sys.argv[2], 16)
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 128
    p = PE(path)
    print("ImageBase=0x%08X ImageSize=0x%X" % (p.base, p.image_size))
    for nm, sva, vs, ra, rs in p.secs:
        print("  %-8s VA=0x%08X VSize=0x%X RawSize=0x%X" % (nm, sva, vs, rs))
    print("--- section of 0x%08X: %s ---" % (va, p.section_of(va)))
    for line in p.dis(va, n):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
