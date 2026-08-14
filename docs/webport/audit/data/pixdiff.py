#!/usr/bin/env python3
"""像素对比: Godot vs Web 逐场景, 产出 diff 图 + 量化 JSON"""
import json, os
from PIL import Image, ImageChops, ImageDraw
import numpy as np

D = '/home/tetsuya/development/Mir3-Research/docs/webport/audit'
PAIRS = ['01_login','02_select','03_game_base','04_walk','05_inventory','06_magic','07_minimap','08_attack','09_chat']
out = {}
for p in PAIRS:
    g = f'{D}/screenshots/{p}_godot.png'
    w = f'{D}/screenshots/{p}_web.png'
    if not os.path.exists(w): w = f'{D}/screenshots/{p}_web.png'
    if not os.path.exists(g) or not os.path.exists(w):
        out[p] = {'error':'missing'}; continue
    gi = Image.open(g).convert('RGB'); wi = Image.open(w).convert('RGB')
    if gi.size != wi.size: wi = wi.resize(gi.size)
    ga = np.asarray(gi).astype(int); wa = np.asarray(wi).astype(int)
    d = np.abs(ga-wa).sum(axis=2)
    diff_mask = d>30
    pct = diff_mask.mean()*100
    # 256x192 降采样对比 (phase1 同口径)
    gs = np.asarray(gi.resize((256,192))).astype(float)
    ws = np.asarray(wi.resize((256,192))).astype(float)
    mad = np.abs(gs-ws).mean()
    corr = np.corrcoef(gs.flatten(), ws.flatten())[0,1]
    # diff 区域 bbox (8px 网格聚合)
    ys,xs = np.where(diff_mask)
    bbox = [int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())] if len(xs) else None
    # 分块统计: 16x12 块, 每块差>30 占比 -> 找最大差块
    h,w_ = diff_mask.shape
    blocks = []
    for by in range(0,h,64):
        for bx in range(0,w_,64):
            blk = diff_mask[by:by+64,bx:bx+64]
            if blk.size: blocks.append((blk.mean()*100,bx,by))
    blocks.sort(reverse=True)
    out[p] = {'pct_diff':round(pct,2),'mad_downsampled':round(mad,2),'corr_downsampled':round(corr,3),
              'bbox_diff':bbox,'top_blocks':[{'pct':round(b[0],1),'x':b[1],'y':b[2]} for b in blocks[:5]]}
    # diff 标注图: 红=差异区
    diff_img = Image.new('RGB',(w_,h),(0,0,0))
    dd = np.asarray(diff_img).copy()
    dd[diff_mask] = [255,40,40]
    # 半透明叠加: 20% 红 + 原图暗化
    overlay = np.asarray(wi).copy()
    ov = (overlay*0.6).astype(np.uint8)
    ov[diff_mask] = [255,40,40]
    Image.fromarray(ov).save(f'{D}/screenshots/{p}_diff.png')
json.dump(out, open(f'{D}/data/pixel-diff.json','w'), ensure_ascii=False, indent=1)
for p,v in out.items():
    print(p, v.get('pct_diff'), v.get('mad_downsampled'), v.get('corr_downsampled'))
