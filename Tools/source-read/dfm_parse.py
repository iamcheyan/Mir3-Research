#!/usr/bin/env python3
"""Delphi 二进制 DFM (TPF0) 解析器 —— 提取窗件控件树与几何。

背景：`reference/mir3-source/Source/Client/FState.dfm`（114 KB）与 `ClMain.dfm`
是 **Delphi 二进制窗件格式**（可打印率约 82%），是窗口坐标/尺寸的**唯一来源** ——
`.pas` 里只有 `DBeltWin: TDWindow;` 这类声明，几何全在 `.dfm`。

格式（Delphi 5/7 TPF0）：
  'TPF0'                     文件头
  Object:  [0x01] TypeName(shortstr) Name(shortstr)
           [props...] [0x00]
           子对象... [0x00]
  Prop:    [0x0F] + Value    (Variant 型属性)
           否则 Name(shortstr) + TypeByte + Value
  TypeByte: 0x01=Char 0x02=Int8 0x03=Int16 0x04=Int32 0x05=Extended 0x06=String
            0x07=Ident 0x08=True 0x09=False 0x0A=Set 0x0B=Enum 0x0C=Double
            0x0D=Binary 0x0E=StringList 0x0F=InlineObject ...
  shortstr: len byte + bytes

用法:
  dfm_parse.py list  <dfm> [--class TDWindow]
  dfm_parse.py tree  <dfm> [--max-depth 3]
  dfm_parse.py json  <dfm> [--out path]
"""
from __future__ import annotations

import argparse
import json
import os
import sys

# 属性值类型标记
VA_CHAR, VA_INT8, VA_INT16, VA_INT32 = 0x01, 0x02, 0x03, 0x04
VA_EXTENDED, VA_STRING, VA_IDENT, VA_TRUE, VA_FALSE = 0x05, 0x06, 0x07, 0x08, 0x09
VA_SET, VA_ENUM, VA_DOUBLE, VA_BINARY, VA_STRINGLIST, VA_COLLECTION = 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F

# 我们关心的几何属性
GEOM = {"Left", "Top", "Width", "Height", "Caption", "Visible", "Enabled"}


class Reader:
    def __init__(self, data: bytes):
        self.d = data
        self.p = 0

    def u8(self) -> int:
        v = self.d[self.p]
        self.p += 1
        return v

    def i8(self) -> int:
        v = self.d[self.p]
        self.p += 1
        return v - 256 if v > 127 else v

    def i16(self) -> int:
        v = int.from_bytes(self.d[self.p:self.p + 2], "little")
        self.p += 2
        return v

    def i32(self) -> int:
        v = int.from_bytes(self.d[self.p:self.p + 4], "little", signed=True)
        self.p += 4
        return v

    def sstr(self) -> str:
        n = self.u8()
        raw = self.d[self.p:self.p + n]
        self.p += n
        # Delphi DFM 用 ANSI(CP949/GB) 存字符串，这里容错解码
        for enc in ("cp949", "gb18030", "latin-1"):
            try:
                return raw.decode(enc)
            except UnicodeDecodeError:
                continue
        return raw.decode("latin-1", "replace")

    def eof(self) -> bool:
        return self.p >= len(self.d)


def read_value(r: Reader, t: int):
    if t == VA_CHAR:
        return chr(r.u8())
    if t == VA_INT8:
        return r.i8()
    if t == VA_INT16:
        return r.i16()
    if t == VA_INT32:
        return r.i32()
    if t == VA_EXTENDED:
        r.p += 10
        return None
    if t == VA_STRING:
        return r.sstr()
    if t == VA_IDENT:
        return r.sstr()
    if t == VA_TRUE:
        return True
    if t == VA_FALSE:
        return False
    if t == VA_SET:
        n = r.u8()
        return [r.sstr() for _ in range(n)]
    if t == VA_ENUM:
        return r.sstr()
    if t == VA_DOUBLE:
        r.p += 8
        return None
    if t == VA_BINARY:
        n = r.i32()
        r.p += n
        return f"<binary {n}B>"
    if t == VA_STRINGLIST:
        out = []
        while True:
            s = r.sstr()
            if s == "":
                break
            out.append(s)
        return out
    if t == VA_COLLECTION:
        # 简化：跳过（内含子项）
        return "<collection>"
    return f"<unknown type {t:#x}>"


def read_object(r: Reader, depth: int = 0, max_depth: int = 99,
               expect_marker: bool = True) -> dict | None:
    """读一个对象（含子对象）。返回 None 表示到流末尾。

    expect_marker: 根对象紧跟 `TPF0` 之后，**没有** 0x01 标记；
    子对象才有。实测 FState.dfm 的根是 `TPF0 07 'TFrmDlg' 06 'FrmDlg' ...`。
    """
    if expect_marker:
        if r.eof():
            return None
        marker = r.u8()
        if marker == 0x00:
            return None
        if marker != 0x01:
            raise ValueError(f"对象标记异常 {marker:#x} @ {r.p-1}")

    cls = r.sstr()
    name = r.sstr()
    props: dict = {}
    children: list = []

    while True:
        if r.eof():
            break
        b = r.u8()
        if b == 0x00:
            break
        # 回退一字节，按「属性名 shortstr」读
        r.p -= 1
        pname = r.sstr()
        if not pname:
            break
        t = r.u8()
        if t == 0x0F:
            # 内联子对象
            child = read_object(r, depth + 1, max_depth, expect_marker=False)
            if child:
                children.append(child)
            continue
        val = read_value(r, t)
        if pname in GEOM:
            props[pname] = val
        else:
            props.setdefault(pname, val)

    # 子对象：紧跟属性区结束的 0x00 之后。
    # 实测 FState.dfm 根对象是 `...属性... 00 00 08 'TDWindow' 09 'DStateWin' ...`
    # —— **两个** 0x00：第一个结束属性区，第二个是本层「无更多子对象」标记的占位。
    # 所以这里要跳过所有 0x00，再从第一个非 0x00 开始读子对象。
    # 本层结束的真正标志是：读完子对象后遇到 0x00 且其后不再是对象起始。
    while not r.eof() and r.d[r.p] == 0x00:
        r.p += 1
        break

    while not r.eof():
        if r.d[r.p] == 0x00:
            break
        child = read_object(r, depth + 1, max_depth, expect_marker=False)
        if child is None:
            break
        children.append(child)

    # 本层收尾的 0x00
    if not r.eof() and r.d[r.p] == 0x00:
        r.p += 1

    return {"class": cls, "name": name, "props": props, "children": children}


def parse(path: str) -> dict:
    with open(path, "rb") as f:
        data = f.read()
    # 实测 FState.dfm 在 TPF0 之前有 17 字节头
    #   ff 0a 00 'TFRMDLG' 00 '0' 10 5f be 01 00
    # 是 Delphi 保存的窗体元信息（类名 + 时间戳），直接定位 TPF0 更稳。
    off = data.find(b"TPF0")
    if off < 0:
        raise SystemExit(f"{path}: 找不到 TPF0 标记（前 16 字节 {data[:16]!r}）")
    r = Reader(data)
    r.p = off + 4
    root = read_object(r, expect_marker=False)
    if root is None:
        raise SystemExit("解析失败：根对象为空")
    return root


def walk(node: dict, depth: int = 0, out: list | None = None):
    if out is None:
        out = []
    p = node["props"]
    out.append({
        "depth": depth,
        "class": node["class"],
        "name": node["name"],
        "left": p.get("Left"), "top": p.get("Top"),
        "width": p.get("Width"), "height": p.get("Height"),
        "caption": p.get("Caption"),
    })
    for c in node["children"]:
        walk(c, depth + 1, out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    for cmd in ("list", "tree", "json"):
        s = sub.add_parser(cmd)
        s.add_argument("dfm")
        s.add_argument("--class", dest="cls", default=None)
        s.add_argument("--max-depth", type=int, default=99)
        s.add_argument("--out", default=None)

    args = ap.parse_args()
    root = parse(args.dfm)
    rows = walk(root)

    if args.cls:
        rows = [r for r in rows if r["class"] == args.cls]
    rows = [r for r in rows if r["depth"] <= args.max_depth]

    if args.cmd == "json":
        out = args.out or "/tmp/dfm.json"
        with open(out, "w", encoding="utf-8") as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
        print(f"已写 {out} ({len(rows)} 项)")
        return 0

    print(f"# {args.dfm}: {len(rows)} 项" + (f" (class={args.cls})" if args.cls else ""))
    for r in rows:
        geo = ""
        if r["left"] is not None:
            geo = f" ({r['left']},{r['top']}) {r['width']}x{r['height']}"
        cap = f"  「{r['caption']}」" if r["caption"] else ""
        indent = "  " * (r["depth"] if args.cmd == "tree" else 0)
        print(f"{indent}{r['class']:24s} {r['name']}{geo}{cap}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
