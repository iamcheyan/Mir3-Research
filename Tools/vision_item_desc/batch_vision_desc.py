#!/usr/bin/env python3
"""批量拼图识别物品图标 -> 写回 item_catalog.json 的 desc 字段。

用法:
  python3 batch_vision_desc.py            # 全量(断点续传)
  python3 batch_vision_desc.py --test     # 只跑 1 批验证
  python3 batch_vision_desc.py --from 3   # 从第 3 批开始

依赖 Hermes venv: ~/.hermes/hermes-agent/venv/bin/python
"""
import base64
import io
import json
import os
import re
import sys
import time
from pathlib import Path

REPO = Path("/home/tetsuya/development/Mir3-Research")
CATALOG = REPO / "docs/quest-design/data/item_catalog.json"
ICONS = REPO / "assets/item-icons"
BATCH_DIR = REPO / "docs/quest-design/data/vision_batches"
BATCH_SIZE = 20          # 5x4 网格
CELL = 52                # 每格像素(图标最大36 + 边距)
LABEL_H = 12             # 顶部编号区高度

BATCH_DIR.mkdir(parents=True, exist_ok=True)

from PIL import Image, ImageDraw, ImageFont

# ---------- 拼图 ----------
def make_grid(items, path):
    """items: [(index_in_catalog, image_id, zh)] 拼成 5x4 网格带编号"""
    cols, rows = 5, 4
    W, H = cols * CELL, rows * CELL + LABEL_H
    img = Image.new("RGB", (W, H), (240, 240, 240))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 11)
    except Exception:
        font = ImageFont.load_default()
    for i, (_, image_id, _) in enumerate(items):
        r, c = divmod(i, cols)
        x, y = c * CELL, LABEL_H + r * CELL
        # 编号
        draw.text((x + 3, y - LABEL_H + 2), str(i + 1), fill=(200, 0, 0), font=font)
        # 图标(居中)
        icon_path = ICONS / f"{image_id}.bmp"
        if not icon_path.exists():
            continue
        im = Image.open(icon_path).convert("RGBA")
        im.thumbnail((CELL - 8, CELL - 8))
        img.paste(im, (x + (CELL - im.size[0]) // 2, y + (CELL - im.size[1]) // 2), im)
    img.save(path)
    return W, H

def img_to_b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()

# ---------- 调用 vision ----------
def call_vision(client, model, b64, prompt):
    resp = client.chat.completions.create(
        model=model,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
            ],
        }],
        max_tokens=2000,
    )
    return resp.choices[0].message.content

def parse_json_loose(text):
    """从模型输出里提取 JSON 数组"""
    m = re.search(r"\[.*\]", text, re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except Exception:
        return None

PROMPT = """这是传奇3游戏物品的背包图标拼图，共20个格子，按5列4行排列。
每个格子左上角有红色数字编号(1-20)。请逐个识别每个图标：
- 描述外观：形状、颜色、材质、特征（简洁，20字以内）
- 推测物品类型（药水/卷轴/技能书/武器/戒指/宝石/矿石/金币/材料等）

严格输出 JSON 数组，格式:
[{"id":1,"desc":"红色药瓶，装液体","type":"药水"}, ...]
只输出 JSON，不要其他文字。"""

def main():
    test_mode = "--test" in sys.argv
    from_idx = 0
    for i, a in enumerate(sys.argv):
        if a == "--from" and i + 1 < len(sys.argv):
            from_idx = int(sys.argv[i + 1])

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    # 有图标的物品
    items = [(i, c["image"], c["zh"]) for i, c in enumerate(catalog)
             if c.get("icon")]
    print(f"待识别: {len(items)} 个物品, 共 {len(items)//BATCH_SIZE + 1} 批")

    # 断点: 已完成的批次
    done = set()
    for f in BATCH_DIR.glob("batch_*.json"):
        m = re.search(r"batch_(\d+)", f.name)
        if m:
            done.add(int(m.group(1)))

    # 初始化 client
    sys.path.insert(0, "/home/tetsuya/.hermes/hermes-agent")
    from agent.auxiliary_client import resolve_vision_provider_client
    provider, client, model = resolve_vision_provider_client(
        provider="openai-codex", model="gpt-5.6-luna", async_mode=False)
    if client is None:
        print("❌ vision client 初始化失败")
        sys.exit(1)
    print(f"✅ client: {provider} / {model}")

    total_batches = (len(items) + BATCH_SIZE - 1) // BATCH_SIZE
    for bi in range(from_idx, total_batches):
        if bi in done and not test_mode:
            continue
        batch = items[bi * BATCH_SIZE:(bi + 1) * BATCH_SIZE]
        grid_path = BATCH_DIR / f"grid_{bi:03d}.png"
        make_grid(batch, grid_path)
        b64 = img_to_b64(grid_path)

        text = None
        for attempt in range(3):
            try:
                text = call_vision(client, model, b64, PROMPT)
                break
            except Exception as e:
                print(f"  批次{bi} 第{attempt+1}次调用失败: {e}")
                time.sleep(5)
        if text is None:
            print(f"  批次{bi} ❌ 3次失败, 跳过")
            continue

        parsed = parse_json_loose(text)
        result = {"batch": bi, "raw": text, "parsed": parsed}
        (BATCH_DIR / f"batch_{bi:03d}.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")

        if parsed:
            n = 0
            for item in parsed:
                if not isinstance(item, dict) or "id" not in item:
                    continue
                idx = item["id"] - 1
                if not (0 <= idx < len(batch)):
                    continue
                cat_idx, image_id, zh = batch[idx]
                desc = str(item.get("desc", "")).strip()
                itype = str(item.get("type", "")).strip()
                if desc:
                    catalog[cat_idx]["desc"] = desc
                    if itype and itype != "None":
                        catalog[cat_idx]["type_guess"] = itype
                    catalog[cat_idx]["desc_source"] = "vision"
                    n += 1
            CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=1), encoding="utf-8")
            print(f"  批次{bi}: ✅ 写入 {n}/{len(batch)} 个描述")
        else:
            print(f"  批次{bi}: ⚠️ JSON 解析失败, 原文已存档")
        if test_mode:
            break
        time.sleep(1)

    vision_n = sum(1 for c in catalog if c.get("desc_source") == "vision")
    print(f"\n完成: vision 描述 {vision_n}/{len(catalog)}")

if __name__ == "__main__":
    main()
