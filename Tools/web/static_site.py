#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""static_site.py — 把 WikiServer 百科渲染成静态站 (GitHub Pages 可部署)。

原理: 抓取运行中的 WikiServer (默认 127.0.0.1:8777), 遍历全部路由,
把 HTML 存成 <out>/<path>.html, 图片/缩略图存成静态文件, 并把页面里的
动态链接 (/maps, /item/xxx) 改写成静态文件路径 (item/xxx.html)。
同时生成 index.html = 首页。

用法:
  python3 static_site.py [--port 8777] [--out _site] [--base /mir2ei]
    --base  站点根路径 (GitHub Pages 项目页是 /mir2ei/, 自定义域名是 /)
"""
import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.parse

DEFAULT_PORT = 8777

# 列表页 + 详情页路由 (按实际 URL 枚举)
# (path, 是否需要按数据展开)
LIST_ROUTES = [
    "/", "/maps", "/monsters", "/items", "/skills", "/npcs", "/quests",
    "/companions", "/stores", "/classes", "/moves", "/sets", "/mines",
    "/safezones", "/fames", "/currencies", "/crafts", "/discipline",
    "/castle", "/guards", "/diff", "/audit", "/terms", "/stages", "/library",
]


def fetch(base, path):
    url = base + path
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return r.read()
    except Exception as e:
        print(f"  ! {path}: {e}")
        return None


def collect_detail_paths(base, port):
    """从数据文件推断详情页路径。"""
    data_dir = "/tmp"
    paths = set()
    try:
        d = json.load(open(os.path.join(data_dir, "wiki_data_v2.json"), encoding="utf-8"))
    except FileNotFoundError:
        return paths
    # 地图: ei_maps name
    for m in d.get("ei_maps", []):
        paths.add("/map/" + m["name"])
    # 怪物: 英文名/中文名
    for m in d.get("monsters", []):
        paths.add("/monster/" + m.get("name", ""))
        zh = m.get("zh")
        if zh and zh != m.get("name"):
            paths.add("/monster/" + zh)
    # 物品
    for it in d.get("items", []):
        paths.add("/item/" + str(it.get("id", "")))
    # 技能
    for s in d.get("skills", []):
        paths.add("/skill/" + str(s.get("id", "")))
    # NPC
    for n in d.get("npcs", []):
        paths.add("/npc/" + str(n.get("id", "")))
    # 任务
    for q in d.get("quests", []):
        paths.add("/quest/" + urllib.parse.quote(q.get("name", "")))
    # 套装
    for s in d.get("sets", []):
        paths.add("/set/" + urllib.parse.quote(s.get("name", "")))
    # 商店
    try:
        st = json.load(open(os.path.join(data_dir, "wiki_stores.json"), encoding="utf-8"))
        for i in range(len(st.get("stores", []))):
            paths.add(f"/store/{i}")
    except FileNotFoundError:
        pass
    return paths


def rewrite_links(html, base_href):
    """把页面里的绝对路径链接改写成静态文件路径。"""
    if isinstance(html, bytes):
        html = html.decode("utf-8")
    # /maps -> maps.html ; /map/0.map -> map/0.map.html ; /item/123 -> item/123.html
    def repl(m):
        href = m.group(1)
        if href.startswith("http") or href.startswith("//"):
            return m.group(0)
        if href.startswith("/"):
            href2 = href[1:]
            if href2 == "":
                href2 = "index.html"
            elif "/" in href2:
                # 详情页: 目录/名字.html
                i = href2.rfind("/")
                href2 = href2[:i] + "/" + urllib.parse.quote(href2[i+1:]) + ".html"
            else:
                href2 = href2 + ".html"
            return f'href="{base_href}{href2}"'
        return m.group(0)
    return re.sub(r'href="([^"]*)"', repl, html)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--out", default="_site")
    ap.add_argument("--base", default="", help="站点根路径, 如 /mir2ei")
    args = ap.parse_args()

    base = f"http://127.0.0.1:{args.port}"
    out = args.out
    os.makedirs(out, exist_ok=True)
    base_href = args.base.rstrip("/") + "/"

    # 1. 列表页
    for p in LIST_ROUTES:
        body = fetch(base, p)
        if body is None:
            continue
        html = rewrite_links(body, base_href)
        rel = (p[1:] or "index") + ".html" if p != "/" else "index.html"
        dst = os.path.join(out, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(html.encode("utf-8") if isinstance(html, str) else html)
        print(f"  {p} -> {rel} ({len(body)}B)")

    # 2. 详情页
    details = collect_detail_paths(base, args.port)
    for p in sorted(details):
        body = fetch(base, p)
        if body is None:
            continue
        html = rewrite_links(body, base_href)
        rel = p[1:].replace("/", "/", 1)
        # /map/0.map -> map/0.map.html
        i = rel.rfind("/")
        rel = rel[:i] + "/" + urllib.parse.unquote(rel[i+1:]) + ".html"
        dst = os.path.join(out, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(html.encode("utf-8") if isinstance(html, str) else html)
    print(f"  {len(details)} detail pages")

    # 3. 缩略图 / 图片
    for d in ("thumb", "img"):
        src_dir = "/tmp/wiki_thumbs" if d == "thumb" else "/tmp/wiki_imgs"
        if not os.path.isdir(src_dir):
            continue
        dst_dir = os.path.join(out, d)
        os.makedirs(dst_dir, exist_ok=True)
        import shutil
        n = 0
        for fn in os.listdir(src_dir):
            if fn.endswith(".png"):
                shutil.copy(os.path.join(src_dir, fn), os.path.join(dst_dir, fn))
                n += 1
        print(f"  {d}: {n} files")

    print(f"Done -> {out}")


if __name__ == "__main__":
    main()
