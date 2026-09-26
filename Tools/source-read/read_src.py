#!/usr/bin/env python3
"""CP949/GB18030 源码读取助手。

reference/mir3-source/Source/** 的 Delphi/C++ 注释是 CP949（韩文），
Mud3-Config/** 是 GB18030（中文）。直接 open() 会乱码或抛异常，
rg/grep 对中文/韩文关键字直接失效 —— 本脚本解决这个问题。

用法:
  read_src.py show   <相对路径> [--start N] [--end M] [--grep PATTERN]
  read_src.py grep   <PATTERN> [--scope Source/Client|Source/GameServer|...]
  read_src.py mirror [--scope ...]        # 转码到 /tmp/mir3-src-utf8/ 镜像目录
  read_src.py enc    <相对路径>           # 报告探测到的编码

路径相对 reference/mir3-source/。输出全部为 UTF-8。
转码产物只落 /tmp，不入库。
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_ROOT = os.path.join(REPO, "reference", "mir3-source")
MIRROR_ROOT = "/tmp/mir3-src-utf8"

# 按路径判定首选编码；CP949 优先（源码注释是韩文），失败再退 GB18030。
CP949_HINT = ("Source/",)
GB_HINT = ("Mud3-Config/",)

TEXT_EXT = {
    ".pas", ".dpr", ".dfm", ".inc", ".cpp", ".h", ".hpp", ".c",
    ".txt", ".ini", ".gen", ".md", ".sln", ".vcproj", ".cfg",
}


def decode(data: bytes, path: str) -> tuple[str, str]:
    """返回 (text, encoding_used)。errors='replace' 保证永不抛异常。"""
    for enc in ("utf-8", "cp949", "gb18030", "latin-1"):
        try:
            return data.decode(enc), enc
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", "replace"), "utf-8/replace"


# 韩文谚文音节（Hangul Syllables U+AC00-U+D7A3）
_HANGUL = re.compile(r"[\uac00-\ud7a3]")
# CJK 统一表意文字（中文）
_CJK = re.compile(r"[\u4e00-\u9fff]")


def _score(text: str) -> int:
    """打分：谚文权重高（本仓库 Source/** 注释以韩文为主）。

    cp949 与 gb18030 都是双字节且都能"成功"解码彼此的字节流，
    单靠 try/except 无法判别 —— 必须看解出来的字符落在哪个区块。
    """
    return len(_HANGUL.findall(text)) * 3 + len(_CJK.findall(text))


def _decode_lossy(data: bytes, enc: str) -> tuple[str, int]:
    """容错解码，返回 (text, 非法字节数)。

    必须容错：实测 `Source/Common/Grobal2.pas` 是**混合编码** —— 整体以 CP949
    韩文注释为主，但夹有 GB18030 中文注释（如 `LoAC: Word; //防御上限`，
    字节 b7c0 d3f9 c9cf cfde，其中 c9cf 不是合法 CP949 双字节）。
    严格解码会在 16998 字节处直接抛异常，从而误判整个文件为 GB18030 并
    输出一屏乱码。
    """
    out: list[str] = []
    bad = 0
    i = 0
    n = len(data)
    while i < n:
        for size in (2, 1):
            chunk = data[i : i + size]
            if len(chunk) < size:
                continue
            try:
                out.append(chunk.decode(enc))
                i += size
                break
            except UnicodeDecodeError:
                continue
        else:
            bad += 1
            out.append("\ufffd")
            i += 1
    return "".join(out), bad


def decode_ordered(data: bytes, path: str) -> tuple[str, str]:
    """按路径给候选顺序，实际用「谚文/汉字计分 + 非法字节惩罚」选最优。

    gb18030 是 cp949 的超集，几乎不会抛异常，所以不能只靠异常判定。
    返回的 encoding 名带 `+mixed` 后缀表示该文件是混合编码。
    """
    rel = path.replace(os.sep, "/")
    if rel.startswith(GB_HINT) or "/Mud3-Config/" in rel:
        order = ["gb18030", "cp949", "utf-8"]
    elif rel.startswith(CP949_HINT) or "/Source/" in rel:
        order = ["cp949", "gb18030", "utf-8"]
    else:
        order = ["utf-8", "cp949", "gb18030"]

    best: tuple[int, str, str, int] | None = None
    for enc in order:
        text, bad = _decode_lossy(data, enc)
        # 非法字节惩罚很重：宁可少认几个汉字，也不要满屏替换符
        sc = _score(text) - bad * 50
        if best is None or sc > best[0]:
            best = (sc, text, enc, bad)
    if best is None:
        return data.decode("utf-8", "replace"), "utf-8/replace"
    _, text, enc, bad = best
    return text, enc + ("+mixed" if bad else "")


def _repair_mixed_lines(raw: bytes, text: str) -> str:
    """逐行修补混合编码：某行 CJK 比谚文多时，整行按 GB18030 重解。

    实测 `Source/Common/Grobal2.pas:419` `LoAC: Word; //防御上限 ok` 的字节是
    b7c0 d3f9 c9cf cfde，全是合法 CP949 双字节，但解出来是「렝徒龜龜」——
    单靠解码器无法判别，只能靠「这一行解出来汉字比谚文多」的启发式。
    韩文行（如 `// 친구설명 변경`）谚文占绝对多数，不会被误改。

    实现走「先重编回字节」路线：容错解码残留的 `\ufffd` 会阻断 cp949 编码，
    因此直接对原始字节按行操作（由调用方传入原始 bytes）。
    """
    out_lines = []
    for raw_line in raw.split(b"\n"):
        line = raw_line.decode("cp949", "replace")
        n_hangul = len(_HANGUL.findall(line))
        n_cjk = len(_CJK.findall(line))
        if n_cjk >= 2 and n_cjk > n_hangul:
            try:
                fixed = raw_line.decode("gb18030")
            except UnicodeDecodeError:
                out_lines.append(line)
                continue
            out_lines.append(fixed)
        else:
            out_lines.append(line)
    return "\n".join(out_lines)


def read_text(path: str) -> tuple[str, str]:
    with open(path, "rb") as f:
        raw = f.read()
    text, enc = decode_ordered(raw, path)
    if enc.endswith("+mixed"):
        text = _repair_mixed_lines(raw, text)
    return text, enc


def resolve(rel: str) -> str:
    p = os.path.join(SRC_ROOT, rel)
    if not os.path.exists(p):
        # 允许传绝对路径
        if os.path.exists(rel):
            return rel
        sys.exit(f"[ERR] 找不到: {rel}\n      基准目录: {SRC_ROOT}")
    return p


def cmd_show(args) -> None:
    p = resolve(args.path)
    text, enc = read_text(p)
    lines = text.splitlines()
    if args.grep:
        pat = re.compile(args.grep, re.IGNORECASE)
        hits = [(i + 1, l) for i, l in enumerate(lines) if pat.search(l)]
        print(f"# {args.path}  [enc={enc}]  {len(hits)} 命中 / {len(lines)} 行")
        for n, l in hits:
            print(f"{n}: {l}")
        return
    start = args.start or 1
    end = args.end or len(lines)
    print(f"# {args.path}  [enc={enc}]  lines={len(lines)}  showing {start}..{end}")
    for i in range(start - 1, min(end, len(lines))):
        print(f"{i + 1}: {lines[i]}")


def iter_files(scope: str):
    base = os.path.join(SRC_ROOT, scope) if scope else SRC_ROOT
    for root, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d not in (".git", ".svn", "__history")]
        for fn in sorted(files):
            if os.path.splitext(fn)[1].lower() in TEXT_EXT:
                yield os.path.join(root, fn)


def cmd_grep(args) -> None:
    pat = re.compile(args.pattern, re.IGNORECASE)
    n_files = n_hits = 0
    for p in iter_files(args.scope):
        try:
            text, enc = read_text(p)
        except OSError:
            continue
        hits = [(i + 1, l) for i, l in enumerate(text.splitlines()) if pat.search(l)]
        if not hits:
            continue
        n_files += 1
        rel = os.path.relpath(p, SRC_ROOT)
        print(f"\n== {rel}  [enc={enc}]")
        for n, l in hits[: args.limit]:
            print(f"{n}: {l.strip()[:200]}")
        if len(hits) > args.limit:
            print(f"   ... 另有 {len(hits) - args.limit} 条")
        n_hits += len(hits)
    print(f"\n# 合计 {n_hits} 命中 / {n_files} 文件", file=sys.stderr)


def cmd_mirror(args) -> None:
    n = 0
    for p in iter_files(args.scope):
        rel = os.path.relpath(p, SRC_ROOT)
        out = os.path.join(MIRROR_ROOT, rel)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        text, enc = read_text(p)
        with open(out, "w", encoding="utf-8") as f:
            f.write(text)
        n += 1
    print(f"转码 {n} 个文件 -> {MIRROR_ROOT}")
    print(f"之后可直接: rg -n '关键字' {MIRROR_ROOT}/Source/Client")


def cmd_enc(args) -> None:
    p = resolve(args.path)
    text, enc = read_text(p)
    print(f"{args.path}: enc={enc} lines={len(text.splitlines())} chars={len(text)}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("show", help="打印文件（可选行区间或正则过滤）")
    s.add_argument("path")
    s.add_argument("--start", type=int)
    s.add_argument("--end", type=int)
    s.add_argument("--grep")
    s.set_defaults(func=cmd_show)

    g = sub.add_parser("grep", help="转码后全文正则搜索（可搜中文/韩文）")
    g.add_argument("pattern")
    g.add_argument("--scope", default="", help="限定子目录，如 Source/Client")
    g.add_argument("--limit", type=int, default=8, help="每文件最多打印条数")
    g.set_defaults(func=cmd_grep)

    m = sub.add_parser("mirror", help="转码整个 scope 到 /tmp/mir3-src-utf8/")
    m.add_argument("--scope", default="")
    m.set_defaults(func=cmd_mirror)

    e = sub.add_parser("enc", help="探测文件编码")
    e.add_argument("path")
    e.set_defaults(func=cmd_enc)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
