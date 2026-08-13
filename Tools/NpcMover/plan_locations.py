#!/usr/bin/env python3
"""NpcMover 规划器: 产出 294 NPC 的位置计划 TSV (npcIndex, mapIndex, x, y) + 审计报告。

匹配策略:
  A 精确   : NPCName == Mud3 脚本名, 直接用 Mud3 坐标 (多数已在位, 计划里为 no-op)
  B 已就位 : 英雄杀来源的中文 NPC, 与 yxs Merchant 一致
  C 语义   : 英文名 Zircon NPC -> 同城镇 Mud3 未占用 Merchant 行 (按店型优先)
  D 推算   : 无 Merchant 行可用 -> 锚点附近可行走空白格
  沙巴克 (map 3) 9 个不动。
"""
import json, sys
from collections import defaultdict, Counter

MAPS_DIR = '/home/tetsuya/development/zircon/Debug/ServerCore/Map'
DUMP = '/tmp/npcmover_dump.json'
MUD3 = '/tmp/mud3_merchant.json'
YXS = '/tmp/yxs_merchant.json'
OUT_TSV = '/tmp/npc_plan.tsv'
OUT_RPT = '/tmp/npc_plan_report.md'

data = json.load(open(DUMP))
npcs, maps = data['npcs'], data['maps']
mud3 = json.load(open(MUD3))
yxs = json.load(open(YXS))
zmap_by_file = {m['file']: m for m in maps}
zmap_by_index = {m['index']: m for m in maps}

# ---------------- .map 可行走性 (与服务端 Map.Load 一致: flag bit0|bit1 都置位) ------------
_wcache = {}
def walkable_grid(mapfile):
    if mapfile in _wcache: return _wcache[mapfile]
    path = f'{MAPS_DIR}/{mapfile}.map'
    try:
        d = open(path, 'rb').read()
    except FileNotFoundError:
        _wcache[mapfile] = None
        return None
    w = d[23] << 8 | d[22]; h = d[25] << 8 | d[24]
    off = 28 + w * h // 4 * 3
    grid = bytearray(w * h)
    for x in range(w):
        base = off + x * h * 14
        for y in range(h):
            if (d[base + y * 14] & 3) == 3: grid[x * h + y] = 1
    _wcache[mapfile] = (w, h, grid)
    return _wcache[mapfile]

def walkable(mapfile, x, y):
    g = walkable_grid(mapfile)
    if g is None: return False
    w, h, grid = g
    return 0 <= x < w and 0 <= y < h and grid[x * h + y] == 1

mud3_by_script = defaultdict(list)
for m in mud3: mud3_by_script[m['script']].append(m)
yxs_by_script = defaultdict(list)
for m in yxs: yxs_by_script[m['script']].append(m)

def parse_pts(s):
    v = [int(t) for t in s.split(',')]
    return list(zip(v[0::2], v[1::2]))

occupied = defaultdict(set)   # mapfile -> {(x,y)} 目标占用格
plan = {}       # npcIndex -> (mapIndex, x, y, method, source, note)
report_map = {}  # idx -> (idx, name, method, old, new, note)
def rpt(idx, name, meth, old, new, note=''):
    """记录审计行; 同一 NPC 后调用覆盖前调用 (避让等终态优先)"""
    report_map[idx] = (idx, name, meth, old, new, note)

def add(idx, mapfile, x, y, method, source, note=''):
    plan[idx] = (zmap_by_file[mapfile]['index'], x, y, method, source, note)
    occupied[mapfile].add((x, y))

# ---- A 精确匹配: Mud3 行序对齐 ----
for n in npcs:
    ms = mud3_by_script.get(n['name'])
    if not ms: continue
    cur = n['region']
    curpts = parse_pts(cur['points'])
    if any(cur['mapFile'] == m['map'] and curpts == [(m['x'], m['y'])] for m in ms):
        for m in ms: occupied[m['map']].add((m['x'], m['y']))
        rpt(n['index'], n['name'], 'A-精确(已在位)', f"{cur['mapFile']}({cur['points']})", '-', 'Mud3,无需改动')
        continue
    same = [p for p in npcs if p['name'] == n['name']]
    m = ms[min(same.index(n), len(ms) - 1)]
    if m['map'] not in zmap_by_file:
        rpt(n['index'], n['name'], 'A-精确(失败)', f"{cur['mapFile']}({cur['points']})", f"{m['map']} 缺图", '目标图缺失')
        continue
    add(n['index'], m['map'], m['x'], m['y'], 'A-精确', f"Mud3:{m['script']}", m['name'])
    rpt(n['index'], n['name'], 'A-精确', f"{cur['mapFile']}({cur['points']})", f"{m['map']}({m['x']},{m['y']})", m['name'])

# ---- 沙巴克不动 ----
for n in npcs:
    if n['region']['mapFile'] == '3':
        rpt(n['index'], n['name'], 'S-沙巴克(不动)', f"3({n['region']['points']})", '-', 'Z版地图,位置正确')

# ---- C 语义分配表 (人工核对 Mud3 自由行后确定; 每格一 NPC) ----
SEMANTIC = {
    # 比奇县 0
    13:('02Weapon_Bichon1','武器店啊康'), 14:('05Book_Bichon','书店店员'), 15:('04Potion_Bichon1','药店老板'),
    16:('07Grocery_Bichon','杂货商'), 17:('08Accessory_Bichon','恩实首饰'), 18:('10ChestnutMarket_Bichon','栗子收购'),
    19:('03Armor_Bichon','怡美防具'), 20:('01Meet_Bichon1','金氏肉店'), 39:('13Move_Bichon1','六面神石'),
    88:('09HorseMarket_Bichon','义贤马市'), 90:('14Quest_Bichon2','图书管理员'), 95:('15Magic_Bichon1','总教头'),
    100:('14Quest_Bichon1','王大人'), 135:('03Shoes_Bichon','慧媛鞋店'), 105:('21WeddingMaker_Bichon','司仪'),
    # 边境城市 1 (Lost Paradise)
    21:('02Weapon_Wooma','王铁匠'), 22:('10Material_DoGwan','天星材料'), 23:('04Potion_Wooma','华玉药店'),
    24:('06Inn_DoGwan','啊天客栈'), 25:('04Potion_DoGwan2','药神'), 26:('10ChestnutMarket_DoGwan','栗子收购'),
    27:('04Potion_DoGwan1','药中'), 28:('01Meet_DoGwan','钱老板肉店'), 42:('13Move_DoGwan','六面神石'),
    91:('14Quest_DoGwan2','书堂玄震'), 96:('14Doctor_DoGwan','万事通'), 101:('14Quest_DoGwan1','士官'),
    # 盘夜村 2 (Banya Village)
    30:('02Weapon_SnakeVally','铁匠啊力'), 31:('10Material_SnakeVally','啊福材料'), 32:('04Potion_SnakeVally','金中医'),
    33:('07Grocery_SnakeVally','流浪卢杂货'), 34:('06Inn_SnakeVally','客栈保管员'), 35:('14Quest_SnakeVally1','蛇谷老太'),
    36:('03Armor_SankeVally','金莲防具'), 37:('09NotBlocker_SnakeVally','蛇谷老人'), 41:('13Move_SnakeVally1','六面神石'),
    92:('14Quest_SnakeVally2','蛇谷老矿夫'), 97:('15Magic_SnakeVally','断乔先生'), 102:('14Doctor_SnakeVally','万事通'),
    106:('13Move_SnakeVally2','六面神石'),
    # 诺玛村 4
    44:('13Move_Oasis','六面神石'), 65:('01Meet_Oasis','屠夫'), 67:('07Grocery_Oasis','洪老板杂货'),
    98:('15Magic_Oasis','唯我独尊'),
    # 沙漠泥堡 5
    60:('02Weapon_Samak','铁汉武器'), 50:('04PotionMake_Samak','老郑药剂'), 52:('07Grocery_Samak','老李杂货'),
    61:('03Shoes_Samak','润真鞋店'), 62:('10Material_Samak','啊宋材料'), 63:('01Meet_Samak','黄老板肉店'),
    43:('13Move_Samak1','六面神石'), 56:('13Move_Samak2','六面神石'), 48:('15Magic_Samak1','武功教头'),
    # 冰城 8
    76:('02Weapon_HalfNight','啊胜武器'), 77:('04Potion_HalfNight','成赫药店'), 78:('07Grocery_HalfNight','中叔杂货'),
    79:('08Accessory_HalfNight','晓华首饰'), 80:('03Armor_HalfNight','晓洋防具'), 118:('13Move_HalfNight1','六面神石'),
    140:('06Inn_HalfNight','满春客栈'),
}
npc_by_idx = {n['index']: n for n in npcs}
for idx, (script, label) in SEMANTIC.items():
    m = mud3_by_script[script][0]
    n = npc_by_idx[idx]
    old = f"{n['region']['mapFile']}({n['region']['points']})"
    add(idx, m['map'], m['x'], m['y'], 'C-语义', f"Mud3:{script}", label)
    rpt(idx, n['name'], 'C-语义', old, f"{m['map']}({m['x']},{m['y']})", f"{label} ({script})")

# ---- D 推算: 扫描锚点附近可行走空白格 ----
def find_free_near(mapfile, anchors, taken, count, min_dist=2, radius=12):
    """anchors 附近找 count 个可行走、彼此及与 taken 距离>=min_dist 的格子。"""
    g = walkable_grid(mapfile)
    if g is None: return []
    w, h, grid = g
    cand = []
    for ax, ay in anchors:
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                x, y = ax + dx, ay + dy
                if not (0 <= x < w and 0 <= y < h): continue
                if not grid[x * h + y]: continue
                cand.append((dx * dx + dy * dy, x, y))
    cand.sort()
    out = []
    for d2, x, y in cand:
        if any((x - px) ** 2 + (y - py) ** 2 < min_dist * min_dist for px, py in list(taken) + out):
            continue
        out.append((x, y))
        if len(out) == count: break
    return out

def scan_place(idxs, mapfile, anchors, label, min_dist=2, radius=12):
    free = find_free_near(mapfile, anchors, occupied[mapfile], len(idxs), min_dist, radius)
    if len(free) < len(idxs):
        print(f'!! {mapfile} 扫描不足: {len(free)}/{len(idxs)}', file=sys.stderr)
    for idx, (x, y) in zip(idxs, free):
        n = npc_by_idx[idx]
        old = f"{n['region']['mapFile']}({n['region']['points']})"
        add(idx, mapfile, x, y, 'D-推算', label, '锚点旁空格')
        rpt(idx, n['name'], 'D-推算', old, f'{mapfile}({x},{y})', label)

# 诺玛村 4 溢出 7 个: 锚点 = 该图全部 Mud3 行
scan_place([66, 68, 69, 70, 93, 103, 136], '4',
           [(m['x'], m['y']) for m in mud3 if m['map'] == '4'], '绿洲村聚落扫描')

# 班尼岛 12 (无 Merchant 行): 最大可行走聚落中心为锚
def largest_cluster(mapfile):
    g = walkable_grid(mapfile)
    w, h, grid = g
    seen = bytearray(w * h); best = []
    for sx in range(w):
        for sy in range(h):
            i = sx * h + sy
            if not grid[i] or seen[i]: continue
            comp = []; stack = [(sx, sy)]; seen[i] = 1
            while stack:
                x, y = stack.pop(); comp.append((x, y))
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = nx * h + ny
                        if grid[j] and not seen[j]: seen[j] = 1; stack.append((nx, ny))
            if len(comp) > len(best): best = comp
    return best

comp = largest_cluster('12')
ccx = sum(p[0] for p in comp) // len(comp); ccy = sum(p[1] for p in comp) // len(comp)
scan_place([45, 81, 82, 83, 84, 85, 86, 94, 99, 104], '12', [(ccx, ccy)],
           f'班尼岛主聚落扫描(中心{ccx},{ccy},聚落{len(comp)}格)', radius=40)

# 比奇水井 [38] (原 9 格区域): 钱庄锚点旁
scan_place([38], '0', [(408, 377)], '比奇城区扫描(钱庄旁)')

# [89] 六面神石: 原站 D10031(199,257) 不可走; Mud3 13Move_HalfTemple 在 D11031(199,257),
# 该格已被 [330] 潘业传送3 占用 -> D11031 锚点旁空格
occupied['D11031'].add((199, 257))
scan_place([89], 'D11031', [(199, 257)], '潘夜神殿3层西部(Mud3:13Move_HalfTemple旁)')

# ---- 其余 NPC 归类 ----
for n in npcs:
    if n["index"] in report_map: continue
    r = n['region']
    old = f"{r['mapFile']}({r['points']})"
    if n['name'] in yxs_by_script and any(r['mapFile'] == m['map'] and r['points'] == f"{m['x']},{m['y']}" for m in yxs_by_script[n['name']]):
        rpt(n['index'], n['name'], 'B-英雄杀(已在位)', old, '-', 'yxs一致')
        continue
    pts = parse_pts(r['points'])
    ok = walkable(r['mapFile'], *pts[0]) if pts else False
    if n['index'] == 320:
        rpt(n['index'], n['name'], 'K-保留', old, '-', f'销售房间室内NPC, 可走={ok}')
    else:
        # yxs 改过坐标的中文 NPC: 可走即保留
        rpt(n['index'], n['name'], 'B-英雄杀(调整)' if n['name'] in yxs_by_script else 'K-保留',
            old, '-', f'可走={ok}')

# ---- 冲突避让: 同格不许两个 NPC (Mud3 权威位优先, 计划中的/自定义的让位) ----
def final_pos(idx):
    if idx in plan:
        mi, x, y = plan[idx][:3]
        return zmap_by_index[mi]['file'], x, y
    n = npc_by_idx[idx]
    pts = parse_pts(n['region']['points'])
    return n['region']['mapFile'], pts[0][0], pts[0][1]

def nearest_free(mapfile, x, y, taken, min_dist=2, max_r=40):
    g = walkable_grid(mapfile)
    if g is None: return None
    w, h, grid = g
    for r in range(1, max_r + 1):
        ring = []
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r: continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and grid[nx * h + ny]:
                    if all((nx - px) ** 2 + (ny - py) ** 2 >= min_dist * min_dist for px, py in taken):
                        ring.append((nx, ny))
        if ring:
            ring.sort(key=lambda p: (p[0] - x) ** 2 + (p[1] - y) ** 2)
            return ring[0]
    return None

# 占位集合补入全部保留 NPC 的现位置
for idx in list(report_map):
    if idx in plan: continue
    try:
        f, x, y = final_pos(idx)
        occupied[f].add((x, y))
    except Exception:
        pass

spots = defaultdict(list)
for n in npcs:
    try:
        f, x, y = final_pos(n['index'])
        spots[(f, x, y)].append(n['index'])
    except Exception:
        pass

def priority(idx):
    """小的留下: Mud3 精确在位 > yxs 在位 > 计划中的 > 其他"""
    n = npc_by_idx[idx]
    if idx not in plan and n['name'] in mud3_by_script: return 0
    if idx not in plan and n['name'] in yxs_by_script: return 1
    if idx in plan: return 2
    return 3

nudged = 0
for (f, x, y), idxs in spots.items():
    if len(idxs) < 2: continue
    idxs = sorted(idxs, key=priority)
    for loser in idxs[1:]:
        nf = nearest_free(f, x, y, occupied[f])
        if nf is None:
            print(f'!! 避让失败: NPC {loser} @ {f}({x},{y})', file=sys.stderr)
            continue
        n = npc_by_idx[loser]
        add(loser, f, nf[0], nf[1], 'E-避让', '同格避让', f'与NPC{idxs[0]}重叠,移至邻格')
        rpt(loser, n['name'], 'E-避让', f'{f}({x},{y})', f'{f}({nf[0]},{nf[1]})',
            f'原与 [{idxs[0]}] {npc_by_idx[idxs[0]]["name"]} 同格')
        nudged += 1
print(f'避让移动 {nudged} 个')

# ---- 校验全部计划坐标可行走 ----
bad = [(i, zmap_by_index[p[0]]['file'], p[1], p[2], p[4]) for i, p in plan.items() if not walkable(zmap_by_index[p[0]]['file'], p[1], p[2])]
mc = Counter(r[2] for r in report_map.values())
print(f'计划移动 {len(plan)} | 分类: ' + ' / '.join(f'{k}={v}' for k, v in sorted(mc.items())) + f' | 总计 {sum(mc.values())}')
print(f'计划坐标不可走: {len(bad)}')
for b in bad: print('  !!', b)

# ---- 输出 TSV + 报告 ----
with open(OUT_TSV, 'w') as f:
    for idx, (mi, x, y, meth, src, note) in sorted(plan.items()):
        f.write(f'{idx}\t{mi}\t{x}\t{y}\n')
with open(OUT_RPT, 'w') as f:
    f.write('# NPC 位置修正计划审计报告\n\n')
    f.write(f'总计 {sum(mc.values())} NPC: ' + ' / '.join(f'{k} {v}' for k, v in sorted(mc.items())) + '\n\n')
    f.write('| Index | NPCName | 方式 | 旧位置 | 新位置 | 说明 | 来源 | 备注 |\n|---|---|---|---|---|---|---|---|\n')
    plan_src = {i: (p[4], p[5]) for i, p in plan.items()}
    for idx, name, meth, old, new, note in sorted(report_map.values(), key=lambda r: (r[2], r[0])):
        src, extra = plan_src.get(idx, ('-', ''))
        f.write(f'| {idx} | {name} | {meth} | {old} | {new} | {note} | {src} | {extra} |\n')
print('TSV ->', OUT_TSV, ' 报告 ->', OUT_RPT)
