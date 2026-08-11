#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dump_all_fix.py — 把 DbMigrationTool dump-all 的 wiki_all.json 转成 WikiServer 需要的形状。

DbMigrationTool dump-all 序列化规则:
  - DBObject 引用 -> {"Index": N, "<Type>Name": "名字"} (名字键 = 目标类型名, 可能为空串)
  - DBBindingList -> [{"Index": N, "<Type>Name": "名字"}]
  - 其余标量原样

WikiServer 期望:
  - 引用直接是目标名字字符串 (d.get("Monster") == "鸡")
  - 列表项是名字字符串列表 (s.get("Items") == ["刀", "剑"])
  - 附带 _identity 键 (= 主名字字段), 供 fallback

转换规则 (对每个表的 rows):
  1. 引用类字段 (值是 dict, 含 Index + <Type>Name) -> 取 <Type>Name 值(字符串);
     若为空 -> 用 Index 反查目标集合的 _identity (按类型名映射到集合名)
  2. 列表类字段 (值是 list of dict) -> 每项取名字字符串; 空 -> 反查
  3. 每个 row 加 _identity = 主名字字段值
"""
import json
import sys

IN = sys.argv[1] if len(sys.argv) > 1 else "/tmp/wiki_all.json"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/wiki_all_fixed.json"

IDENTITY_FIELDS = [
    "NPCName", "ItemName", "MonsterName", "SetName", "QuestName",
    "Description", "FileName", "Name", "Monster", "Item",
]


def identity_of(row):
    for f in IDENTITY_FIELDS:
        v = row.get(f)
        if isinstance(v, str) and v:
            return v
    return None


class Flattener:
    def __init__(self, data):
        # 类型名 -> 集合名 映射 (去掉 Info 后缀, e.g. ItemInfo -> ItemInfo)
        # WikiServer rows("X") 用的是集合名 (DropInfo/ItemInfo/...)
        self.data = data
        # 预建: 类型名 -> {Index: _identity}
        self.idx_by_type = {}
        for table, info in data.items():
            for row in info["rows"]:
                idv = identity_of(row)
                if idv is not None:
                    self.idx_by_type.setdefault(table, {})[row.get("Index")] = idv

    def type_to_table(self, type_name):
        # "ItemInfo" -> "ItemInfo"; "QuestTaskMonsterDetails" 等直接同名
        return type_name

    def lookup(self, type_name, index):
        t = self.type_to_table(type_name)
        m = self.idx_by_type.get(t, {})
        return m.get(index)

    def flatten(self, v):
        if isinstance(v, dict):
            if "Index" in v:
                # DBObject 引用
                nm = None
                for k, val in v.items():
                    if k != "Index" and isinstance(val, str) and val:
                        nm = val
                        break
                if nm:
                    return nm
                # 空名字 -> 反查
                idx = v.get("Index")
                if idx is not None:
                    # 找该 dict 的类型名键 (去掉值)
                    for k in v:
                        if k != "Index":
                            got = self.lookup(k, idx)
                            if got:
                                return got
                return idx
            return {k: self.flatten(x) for k, x in v.items()}
        if isinstance(v, list):
            out = []
            for item in v:
                if isinstance(item, dict) and "Index" in item:
                    nm = None
                    for k, val in item.items():
                        if k != "Index" and isinstance(val, str) and val:
                            nm = val
                            break
                    if not nm:
                        idx = item.get("Index")
                        for k in item:
                            if k != "Index":
                                got = self.lookup(k, idx)
                                if got:
                                    nm = got
                                    break
                    out.append(nm if nm is not None else item.get("Index"))
                else:
                    out.append(self.flatten(item))
            return out
        return v


def main():
    d = json.load(open(IN, encoding="utf-8"))
    fl = Flattener(d)
    out = {}
    for table, info in d.items():
        new_rows = []
        for row in info["rows"]:
            nr = {k: fl.flatten(v) for k, v in row.items()}
            idv = identity_of(nr)
            if idv is not None:
                nr["_identity"] = idv
            new_rows.append(nr)
        out[table] = {"count": len(new_rows), "rows": new_rows}

    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False)
    print(f"fixed {len(out)} tables -> {OUT}")


if __name__ == "__main__":
    main()
