#!/usr/bin/env python3
"""Mir3 Preview 源码的线格式编解码（EDCode.pas 的 Python 移植）。

用途：验证本仓库对「消息包头 + 6bit 编码 + 防外挂校验」的静态推断，
并为将来 wsgateway/协议对照提供参考实现。

来源（逐行对应，证据等级 secondary-source）：
  reference/mir3-source/Source/Common/EDCode.pas
    - Encode6BitBuf       :154-211
    - Decode6BitBuf       :213-274
    - EncodeMessage       :417-435   （Etc 校验字段在此生成）
    - DecodeMessage       :369-381
    - EncodeString        :438-447
    - DecodeString        :384-393
  reference/mir3-source/Source/Common/Grobal2.pas
    - TMsgHeader          :9-17
    - TDefaultMessage     :20-28
    - MakeDefaultMsg      :2840-2851 （Etc/Etc2 的 hid 掩码编码）

用法:
  edcode.py selftest                 # 跑内置测试向量
  edcode.py encode-string "hello"    # 6bit 编码
  edcode.py decode-string <str>      # 6bit 解码
  edcode.py make-msg --ident 1033    # 构造并编码一条 TDefaultMessage
"""
from __future__ import annotations

import argparse
import sys

# ---------------------------------------------------------------- 常量

# EDCode.pas:185/191/195/204 —— 6bit 值加偏移变成可打印字符
CHAR_OFFSET = 0x3C  # '=' 的 ASCII

# 全局公钥，默认值见 EDCode.pas:117 `g_EndeKey: WORD = ($6501)`。
# 可被 LoadPublicKey(fname)（EDCode.pas:125-140）从文本文件首行覆盖，
# 服务端配置里对应 `Mud3-Config/Envir/enckey.txt`（源码字符串常量）。
DEFAULT_KEY = 0x6501

# ---------------------------------------------------------------- 6bit 编解码


def _key_xor(key: int) -> int:
    """源码 `HIBYTE(g_EndeKey) + LOBYTE(g_EndeKey)`（EDCode.pas:177/247）。

    注意是**加法**不是 XOR —— 16 位 key 的高字节 + 低字节。
    """
    return ((key >> 8) & 0xFF) + (key & 0xFF)


def encode_6bit(data: bytes, key: int = DEFAULT_KEY, destlen: int = 1024) -> str:
    """对应 EDCode.pas:154-211 `Encode6BitBuf`。

    每字节先做两次 XOR：
      1. `ch ^ (((i + 5) * 2) + 3)`   —— i 是**输入字节下标**
      2. `ch ^ key_xor`               —— 全局公钥
    然后按 6bit 分组，每组 +0x3C 变可打印字符。
    """
    kx = _key_xor(key)
    restcount = 0
    rest = 0
    destpos = 0
    out: list[str] = []

    for i in range(len(data)):
        if destpos >= destlen:
            break
        ch = data[i] & 0xFF

        ch ^= (((i + 5) * 2) + 3) & 0xFF
        ch ^= kx & 0xFF

        made = (rest | (ch >> (2 + restcount))) & 0x3F
        rest = ((ch << (8 - (2 + restcount))) >> 2) & 0x3F
        restcount += 2

        if restcount < 6:
            out.append(chr(made + CHAR_OFFSET))
            destpos += 1
        else:
            if destpos < destlen - 1:
                out.append(chr(made + CHAR_OFFSET))
                out.append(chr(rest + CHAR_OFFSET))
                destpos += 2
            else:
                out.append(chr(made + CHAR_OFFSET))
                destpos += 1
            restcount = 0
            rest = 0

    if restcount > 0:
        out.append(chr(rest + CHAR_OFFSET))
        destpos += 1

    return "".join(out)


def decode_6bit(text: str, key: int = DEFAULT_KEY, buflen: int = 1024) -> bytes:
    """对应 EDCode.pas:213-274 `Decode6BitBuf`。

    与编码是**同一套变换**（XOR 自反）：解码时 `bufpos` 代替了编码时的 `i`。
    合法的 6bit 字符范围是 `[0x3C, 0x3C+64]`；越界即判为非法整包丢弃。
    """
    kx = _key_xor(key)
    MASKS = {2: 0xFC, 3: 0xF8, 4: 0xF0, 5: 0xE0, 6: 0xC0}

    bitpos = 2
    madebit = 0
    bufpos = 0
    tmp = 0
    out = bytearray()

    for i in range(len(text)):
        c = ord(text[i])
        if 0 <= c - CHAR_OFFSET <= 64:
            ch = c - CHAR_OFFSET
        else:
            return b""  # 源码：bufpos := 0; break —— 整包作废

        if bufpos >= buflen:
            break

        if (madebit + 6) >= 8:
            _byte = (tmp | ((ch & 0x3F) >> (6 - bitpos))) & 0xFF
            _byte ^= kx & 0xFF
            _byte ^= (((bufpos + 5) * 2) + 3) & 0xFF
            out.append(_byte)
            bufpos += 1
            madebit = 0
            if bitpos < 6:
                bitpos += 2
            else:
                bitpos = 2
                continue

        tmp = (ch << bitpos) & MASKS[bitpos]
        madebit += 8 - bitpos

    return bytes(out)


# ---------------------------------------------------------------- 防外挂校验


def make_etc_fields(hid: int = 200) -> tuple[int, int]:
    """对应 Grobal2.pas:2848-2849 `MakeDefaultMsg` 的 Etc/Etc2 生成。

        Etc  := ((HIWORD(hid) and $A3) or $58) xor $8A;
        Etc2 := ((LOWORD(hid) and $EC) or $28) xor $A9;

    注意：这两行与 `EncodeMessage` 里对 Etc 的覆写是**两套不同机制**。
    MakeDefaultMsg 生成的是 hid 的掩码编码；EncodeMessage 随后会把 Etc
    覆写成真正的防外挂校验值（低字节 RandKey^8，高字节校验和）。
    """
    etc = ((((hid >> 16) & 0xA3) | 0x58) ^ 0x8A) & 0xFF
    etc2 = (((hid & 0xFFFF) & 0xEC) | 0x28) ^ 0xA9
    return etc, etc2


def checksum(recog: int, ident: int, param: int, tag: int, series: int,
             key: int = DEFAULT_KEY) -> int:
    """对应 EDCode.pas:427 的校验和部分。

        ((Recog and $57CD) + (Ident or $48) + (Param or $30)
         + (Tag and $2D) + Series) xor GetPublicKey

    返回 16 位结果（源码用 BYTE() 截断后放进 Etc 高字节，见 encode_message）。
    """
    s = ((recog & 0x57CD) + (ident | 0x48) + (param | 0x30)
         + (tag & 0x2D) + series)
    return (s ^ key) & 0xFFFF


def old_checksum(recog: int, ident: int, param: int, tag: int, series: int,
                 key: int = DEFAULT_KEY) -> int:
    """EDCode.pas:425 注释掉的 **old version**（无 RandKey 混淆）。

        smsg.Etc := WORD(((Recog and $57CD) + (Ident or $48) + (Param or $30)
                          + (Tag and $2D) + Series) xor GetPublicKey);

    保留用于对照：能解释早期抓包与当前版本 Etc 高字节一致、低字节为 0 的现象。
    """
    return checksum(recog, ident, param, tag, series, key)


# ---------------------------------------------------------------- 消息


def make_default_msg(ident: int, recog: int = 0, param: int = 0,
                     tag: int = 0, series: int = 0, hid: int = 200) -> dict:
    """对应 Grobal2.pas:2840-2851。"""
    etc, etc2 = make_etc_fields(hid)
    return {
        "Recog": recog, "Ident": ident, "Param": param,
        "Tag": tag, "Series": series, "Etc": etc, "Etc2": etc2,
    }


def pack_msg(msg: dict) -> bytes:
    """TDefaultMessage 的线布局（Grobal2.pas:20-28，注释里的字节数）。

        Recog  : integer  4
        Ident  : word     2
        Param  : word     2
        Tag    : word     2
        Series : word     2
        Etc    : word     2
        Etc2   : word     2
        ---------------------
        合计 16 字节，小端

    Delphi 的 `word` 是**无符号** 16 位，`integer` 是**有符号** 32 位，
    所以格式串是 `i` + 6 个 `H`（不是 `h`）。
    """
    import struct
    return struct.pack("<iHHHHHH",
                       msg["Recog"] & 0xFFFFFFFF if msg["Recog"] >= 0 else msg["Recog"],
                       msg["Ident"] & 0xFFFF, msg["Param"] & 0xFFFF,
                       msg["Tag"] & 0xFFFF, msg["Series"] & 0xFFFF,
                       msg["Etc"] & 0xFFFF, msg["Etc2"] & 0xFFFF)


def encode_message(msg: dict, key: int = DEFAULT_KEY, rand_key: int | None = None) -> str:
    """对应 EDCode.pas:417-435 `EncodeMessage`。

    会**覆写** msg['Etc']：低字节 = RandKey ^ 8，高字节 = 校验和 & 0xFF。
    返回 6bit 编码后的字符串。
    """
    import random
    rk = random.randrange(256) if rand_key is None else rand_key
    csum = checksum(msg["Recog"], msg["Ident"], msg["Param"],
                    msg["Tag"], msg["Series"], key)
    low = (rk ^ 0x08) & 0xFF
    high = ((csum ^ (key ^ rk)) & 0xFF)
    msg = dict(msg)
    msg["Etc"] = (low | (high << 8)) & 0xFFFF
    return encode_6bit(pack_msg(msg), key)


def decode_message(text: str, key: int = DEFAULT_KEY) -> dict:
    """对应 EDCode.pas:369-381 `DecodeMessage`。"""
    import struct
    raw = decode_6bit(text, key, 1024)
    if len(raw) < 16:
        return {}
    r, ident, param, tag, series, etc, etc2 = struct.unpack("<iHHHHHH", raw[:16])
    return {"Recog": r, "Ident": ident, "Param": param, "Tag": tag,
            "Series": series, "Etc": etc, "Etc2": etc2}


# ---------------------------------------------------------------- 自测


def selftest() -> bool:
    fails = []

    # 1. 6bit 往返（含 0 长度与边界）
    for payload in (b"", b"a", b"hello world", bytes(range(256)), b"\x00" * 7):
        enc = encode_6bit(payload)
        dec = decode_6bit(enc)
        if dec != payload:
            fails.append(f"6bit 往返失败: {payload[:16]!r} -> {dec[:16]!r}")

    # 2. 非零公钥往返（含真实默认 key 0x6501）
    for key in (0x6501, 0x1234, 0xFFFF, 0x00FF):
        payload = b"Mir3 protocol test \x01\x02\x03"
        dec = decode_6bit(encode_6bit(payload, key), key)
        if dec != payload:
            fails.append(f"公钥 {key:#x} 往返失败")

    # 2b. key_xor 必须是 高字节+低字节（EDCode.pas:177 的加法，不是 XOR）
    if _key_xor(0x6501) != (0x65 + 0x01):
        fails.append(f"key_xor(0x6501) 应为 0x66，实得 {_key_xor(0x6501):#x}")

    # 3. 编码输出必须落在可打印区间 [0x3C, 0x3C+64]
    enc = encode_6bit(bytes(range(256)))
    bad = [c for c in enc if not (0 <= ord(c) - CHAR_OFFSET <= 64)]
    if bad:
        fails.append(f"编码输出越界: {bad[:8]}")

    # 4. 非法字符应导致整包作废（返回空）
    if decode_6bit("abc\x01def") != b"":
        fails.append("非法字符未导致整包作废")

    # 5. TDefaultMessage 线长必须 16 字节
    msg = make_default_msg(1033, recog=12345, param=1, tag=2, series=3)
    if len(pack_msg(msg)) != 16:
        fails.append("TDefaultMessage 线长不是 16")

    # 6. 消息往返（固定 RandKey 保证确定性）
    enc = encode_message(msg, key=DEFAULT_KEY, rand_key=0x5A)
    dec = decode_message(enc, key=DEFAULT_KEY)
    for f in ("Recog", "Ident", "Param", "Tag", "Series", "Etc2"):
        if dec.get(f) != msg[f]:
            fails.append(f"消息往返字段 {f} 不一致: {dec.get(f)} vs {msg[f]}")

    # 7. Etc 低字节必须是 RandKey ^ 8
    if (dec["Etc"] & 0xFF) != (0x5A ^ 0x08):
        fails.append(f"Etc 低字节错误: {dec['Etc'] & 0xFF:#x}")

    # 8. Etc 高字节必须是 (校验和 ^ key ^ randkey) & 0xFF
    cs = checksum(msg["Recog"], msg["Ident"], msg["Param"], msg["Tag"], msg["Series"], DEFAULT_KEY)
    want_high = (cs ^ (DEFAULT_KEY ^ 0x5A)) & 0xFF
    if (dec["Etc"] >> 8) != want_high:
        fails.append(f"Etc 高字节错误: {dec['Etc'] >> 8:#x} vs {want_high:#x}")

    # 9. MakeDefaultMsg 的 hid 掩码（Grobal2.pas:2848-2849 逐字计算）
    #    hid=200=0xC8: HIWORD=0x0, LOWORD=0xC8
    #      Etc  = ((0x0 & 0xA3) | 0x58) ^ 0x8A = 0xD2
    #      Etc2 = ((0xC8 & 0xEC) | 0x28) ^ 0xA9 = 0x41
    etc, etc2 = make_etc_fields(200)
    if (etc, etc2) != (0xD2, 0x41):
        fails.append(f"hid=200 掩码值变了: {etc:#x} {etc2:#x}")

    # 9b. hid 高 16 位参与 Etc（验证 HIWORD 分支确实被用到）
    etc_hi, _ = make_etc_fields(0x0001_00C8)
    if etc_hi != ((((0x0001 & 0xA3) | 0x58) ^ 0x8A) & 0xFF):
        fails.append("hid HIWORD 分支未生效")

    # 10. old_checksum 与 checksum 在 key=0 时应相同
    if old_checksum(1, 2, 3, 4, 5, 0) != checksum(1, 2, 3, 4, 5, 0):
        fails.append("old_checksum 与 checksum 在 key=0 时不一致")

    for f in fails:
        print(f"[FAIL] {f}")
    print()
    print("EDCODE SELFTEST", "PASS" if not fails else "FAIL")
    return not fails


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("selftest").set_defaults(func=lambda a: 0 if selftest() else 1)

    s = sub.add_parser("encode-string")
    s.add_argument("text")
    s.add_argument("--key", type=lambda x: int(x, 0), default=DEFAULT_KEY)
    s.set_defaults(func=lambda a: (print(encode_6bit(a.text.encode("utf-8"), a.key)), 0)[1])

    d = sub.add_parser("decode-string")
    d.add_argument("text")
    d.add_argument("--key", type=lambda x: int(x, 0), default=DEFAULT_KEY)
    d.set_defaults(func=lambda a: (print(repr(decode_6bit(a.text, a.key))), 0)[1])

    m = sub.add_parser("make-msg")
    m.add_argument("--ident", type=lambda x: int(x, 0), required=True)
    m.add_argument("--recog", type=lambda x: int(x, 0), default=0)
    m.add_argument("--param", type=lambda x: int(x, 0), default=0)
    m.add_argument("--tag", type=lambda x: int(x, 0), default=0)
    m.add_argument("--series", type=lambda x: int(x, 0), default=0)
    m.add_argument("--key", type=lambda x: int(x, 0), default=DEFAULT_KEY)
    m.add_argument("--rand", type=lambda x: int(x, 0), default=0)
    m.set_defaults(func=lambda a: (
        print(encode_message(make_default_msg(a.ident, a.recog, a.param, a.tag, a.series),
                             a.key, a.rand)), 0)[1])

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
