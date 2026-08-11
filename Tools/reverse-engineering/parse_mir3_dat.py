#!/usr/bin/env python3
"""parse_mir3_dat.py — decode the EI 3.0 ORIGIN server (Mud3) data files.

Decodes the three XOR-obfuscated binary tables (stditem.dat / magic.dat /
monster.dat) and the two text tables (Mapinfo.txt / Merchant.txt) used by the
EIServer.exe game server, so client UI evidence can be cross-referenced
against the server's business data.

Ground truth (primary-static, from EIServer.exe loader disassembly):
  * every .dat body is XOR-obfuscated with a single-byte key;
    the leading count dword is NOT obfuscated;
  * stditem loader 0x4957e0 : GetMem(0xB8=184), seek(idx*0xB8+4), XOR key 4
    (xor-4 helper 0x4957a4, constant also at 0x4953cc)
  * monster loader 0x495c88: read 4-byte count, GetMem(0xFC=252),
    seek(idx*0xFC+4), XOR key 9 (xor-9 helper 0x495c4c, constant 0x495c74)
  * magic   recsz 0x78=120 (constant 0x495686 area), XOR key 0x11 (0x495620)
  * names are GBK ShortStrings (len byte + bytes) at:
    stditem +152, magic +104, monster +229
  * stditem +0 dword = sequential item index; monster +248 dword = type id

Self-contained: no third-party deps. Records are returned as dicts of
bytearray fields; the -d/--dump option prints a human-readable table.
"""

import argparse
import sys

STDITEM = {"recsz": 184, "xor_key": 0x04, "name_off": 152}
MAGIC = {"recsz": 120, "xor_key": 0x11, "name_off": 104}
MONSTER = {"recsz": 252, "xor_key": 0x09, "name_off": 229}


def _gbk(b):
    try:
        return b.decode("gbk", "replace")
    except Exception:
        return repr(b)


def decode_dat(path, recsz, xor_key, name_off, count_hint=None):
    """Decode one XOR-obfuscated .dat. Returns (count, records[list of
    bytearray], body_len, nominal_len), or (None, None, 0, 0) on short file.
    The leading count dword is raw; the body is XOR'd byte-wise."""
    """Decode one XOR-obfuscated .dat. Returns (count, records[list of
    bytearray]), or (count, None) if the body size does not fit the nominal
    layout. The leading count dword is raw; the body is XOR'd byte-wise."""
    raw = open(path, "rb").read()
    if len(raw) < 4:
        return None, None
    count = int.from_bytes(raw[0:4], "little")
    body = bytes(b ^ xor_key for b in raw[4:])
    nominal = count * recsz
    if len(body) != nominal:
        # truncated tail: still decode the full records we have
        nfull = len(body) // recsz
        recs = [bytearray(body[i * recsz:(i + 1) * recsz]) for i in range(nfull)]
        return count, recs, len(body), nominal
    recs = [bytearray(body[i * recsz:(i + 1) * recsz]) for i in range(count)]
    return count, recs, len(body), nominal


def shortstring(rec, off):
    n = rec[off]
    if n <= 0 or n > 32:
        return ""
    return _gbk(bytes(rec[off + 1:off + 1 + n]))


def dword(rec, off):
    return int.from_bytes(bytes(rec[off:off + 4]), "little")


def word(rec, off):
    return int.from_bytes(bytes(rec[off:off + 2]), "little")


def dump_stditem(rec):
    return {
        "index": dword(rec, 0),
        "name": shortstring(rec, 152),
        "cat36": rec[36], "shape40": rec[40], "type44": rec[44],
        "d64": dword(rec, 64), "looks68": dword(rec, 68), "d72": dword(rec, 72),
        "b76": rec[76], "b80": rec[80], "b88": rec[88], "b92": rec[92],
        "b104": rec[104], "b108": rec[108],
        "d132": dword(rec, 132), "need140": rec[140], "price144": dword(rec, 144),
        "b148": rec[148],
    }


def dump_magic(rec):
    return {
        "name": shortstring(rec, 104),
        "d0": dword(rec, 0), "d4": dword(rec, 4), "d8": dword(rec, 8),
        "d12": dword(rec, 12), "d16": dword(rec, 16), "d20": dword(rec, 20),
        "d24": dword(rec, 24), "d28": dword(rec, 28), "d32": dword(rec, 32),
        "d36": dword(rec, 36), "d40": dword(rec, 40),
    }


def dump_monster(rec):
    return {
        "id248": dword(rec, 248) if len(rec) >= 252 else None,
        "name": shortstring(rec, 229),
        "d20": dword(rec, 20), "d24": dword(rec, 24), "d28": dword(rec, 28),
        "d32": dword(rec, 32), "d36": dword(rec, 36), "d40": dword(rec, 40),
        "d44": dword(rec, 44), "d48": dword(rec, 48), "d52": dword(rec, 52),
        "d56": dword(rec, 56), "d60": dword(rec, 60), "d64": dword(rec, 64),
        "d68": dword(rec, 68), "d72": dword(rec, 72),
        "d104": dword(rec, 104), "d108": dword(rec, 108),
        "d112": dword(rec, 112), "d116": dword(rec, 116), "d120": dword(rec, 120),
        "d124": dword(rec, 124), "d128": dword(rec, 128), "d132": dword(rec, 132),
        "d140": dword(rec, 140), "d144": dword(rec, 144), "d148": dword(rec, 148),
    }


def parse_mapinfo(path):
    """Mapinfo.txt: '[stem 中文名 flag] DAY horse KSPD' with optional tail
    teleport-link lines '02_002 90,15 -> 02_003 22,83'. Stems are STRINGS
    (map file stems like '0', '0_003', '01', 'Island01'), NOT numeric ids.
    GBK encoded. Returns list of dicts (stem, name, flag, flags, tail)."""
    out = []
    for line in open(path, "rb").read().decode("gbk", "replace").splitlines():
        line = line.strip()
        if not line or line.startswith(";") or line.startswith(";;"):
            continue
        # teleport links: 'A 90,15 -> B 22,83' -> skip, they are not maps
        if "->" in line:
            continue
        if not (line.startswith("[") and "]" in line):
            continue
        head, _, tail = line.partition("]")
        head = head[1:].strip()
        parts = head.split()
        if len(parts) < 2:
            continue
        stem = parts[0]
        name = parts[1]
        flag = parts[2] if len(parts) > 2 else ""
        out.append({"stem": stem, "name": name, "flag": flag,
                    "flags": tail.split(), "tail_raw": tail.strip()})
    return out


def parse_merchant(path):
    """Merchant.txt (header: 'filename Map X Y Name Face Body Sabuk'):
    'stem  map  x  y  中文名  face  body' — e.g.
    '01Meet_Bichon1 0 446 405 金氏 0 11'.  GBK encoded.
    Returns list of dicts (line, stem, map, x, y, name, face, body)."""
    out = []
    for i, line in enumerate(open(path, "rb").read().decode("gbk", "replace").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith(";") or line.startswith(";;"):
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        rec = {"line": i, "stem": parts[0], "map": parts[1],
               "x": parts[2], "y": parts[3], "name": parts[4]}
        if len(parts) > 5:
            rec["face"] = parts[5]
        if len(parts) > 6:
            rec["body"] = parts[6]
        if len(parts) > 7:
            rec["sabuk"] = parts[7]
        out.append(rec)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-d", "--dump", action="store_true", help="print human-readable dump")
    ap.add_argument("--stditem", default="/tmp/nas_mnt/NAS/TMP/Mud3/Envir/stditem.dat")
    ap.add_argument("--magic", default="/tmp/nas_mnt/NAS/TMP/Mud3/Envir/magic.dat")
    ap.add_argument("--monster", default="/tmp/nas_mnt/NAS/TMP/Mud3/Envir/monster.dat")
    ap.add_argument("--mapinfo", default="/tmp/nas_mnt/NAS/TMP/Mud3/Envir/Mapinfo.txt")
    ap.add_argument("--merchant", default="/tmp/nas_mnt/NAS/TMP/Mud3/Envir/Merchant.txt")
    ap.add_argument("--items", default="金创药（小）,魔法药（小）,金创药（中）,魔法药（中）,肉,干肉,包子,布衣（男）,布衣（女）,轻型盔甲（男）,木剑,铁剑,青铜剑,短剑,凝霜,蜡烛,火球术,治愈术,基本剑术,精神力战法,魔法盾")
    ap.add_argument("--monsters", default="稻草人,鸡,鹿,白野猪,钉耙猫,多钩猫,蛤蟆,牛老道,羊,守卫武将,赤月恶魔,祖玛教主,蝎蛇,七点白蛇,食人花")
    ap.add_argument("--magics", default="基本剑术,半月弯刀,爆裂火焰,冰咆哮,冰沙掌,乾坤大挪移,斗转星移,冰月神掌,冰月震天")
    args = ap.parse_args()

    ok = True
    # --- stditem ---
    count, recs, blen, nominal = decode_dat(args.stditem, **STDITEM)
    print(f"stditem.dat: header count={count} body={blen}B nominal={count}*184={nominal}B")
    if count is not None and recs is not None:
        print(f"  records decoded: {len(recs)}")
    else:
        ok = False

    # --- magic ---
    count, recs, blen, nominal = decode_dat(args.magic, **MAGIC)
    print(f"magic.dat: header count={count} body={blen}B nominal={count}*120={nominal}B")
    if count is not None and recs is not None:
        print(f"  records decoded: {len(recs)}")
    else:
        ok = False

    # --- monster ---
    count, recs, blen, nominal = decode_dat(args.monster, **MONSTER)
    print(f"monster.dat: header count={count} body={blen}B nominal={count}*252={nominal}B")
    if count is not None and recs is not None:
        print(f"  records decoded: {len(recs)}  (tail-short: body is {blen-nominal:+d}B vs nominal)")
    else:
        ok = False

    if args.dump:
        want = set(args.items.split(","))
        for kind, name_off in (("stditem", 152),):
            count, recs, blen, nominal = decode_dat(args.stditem, **STDITEM)
            if recs is None:
                continue
            print("\n== stditem (required items) ==")
            for i, rec in enumerate(recs):
                nm = shortstring(rec, name_off)
                if nm in want:
                    print(f"  rec{i}: {dump_stditem(rec)}")

        want = set(args.monsters.split(","))
        count, recs, blen, nominal = decode_dat(args.monster, **MONSTER)
        if recs is not None:
            print("\n== monster (required rows) ==")
            for i, rec in enumerate(recs):
                nm = shortstring(rec, 229)
                if nm in want:
                    print(f"  rec{i}: {dump_monster(rec)}")

        want = set(args.magics.split(","))
        count, recs, blen, nominal = decode_dat(args.magic, **MAGIC)
        if recs is not None:
            print("\n== magic (required rows) ==")
            for i, rec in enumerate(recs):
                nm = shortstring(rec, 104)
                if nm in want:
                    print(f"  rec{i}: {dump_magic(rec)}")

        maps = parse_mapinfo(args.mapinfo)
        print(f"\n== Mapinfo.txt: {len(maps)} map entries ==")
        need = {"0", "4", "41", "42", "43", "44", "544"}
        shown = 0
        for m in maps:
            if m["stem"] in need or shown < 30:
                print(f"  {m['stem']:<10} {m['name']}  flag={m['flag']!r}")
                shown += 1

        mers = parse_merchant(args.merchant)
        print(f"\n== Merchant.txt: {len(mers)} NPCs (first 12) ==")
        for m in mers[:12]:
            print(f"  line{m['line']}: {m}")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
