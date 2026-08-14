# webres — Zircon 客户端 Web 移植资源瘦身管线 (阶段0 Spike)

`.Zl` 帧库 → 逐帧 lossless WebP + `manifest.json`，附 FastAPI 按需加载原型服务。

## 文件

| 文件 | 用途 |
|---|---|
| `decode_zl_webp.py` | 解码管线: `.Zl` → `WebData/{lib}/{帧号}.webp` + `manifest.json` |
| `serve.py` | FastAPI 静态资源服务 (127.0.0.1:8821) |
| `ESTIMATE.md` | 体积估算数据 (Interface.Zl 全量实测 + Interface1c 抽样外推 + 目录组成) |

## 依赖

- Python: `/home/tetsuya/mir3-venv/bin/python`
- 包: Pillow (WebP 编码), numpy, texture2ddecoder, fastapi, uvicorn (venv 已装)
- 解码核心: `Tools/common/zlsdk.py` (`ZlLibrary`, 支持 ZL2 容器 codec 0=Dxt1/1=Dxt5/2=Bgra32/3=Bc7/4=Png 与 legacy v0/v1 DXT 容器)。系统无 cwebp 二进制, 统一用 Pillow 的 `save(path, "WEBP", lossless=True)`。

## 用法

```bash
PY=/home/tetsuya/mir3-venv/bin/python
DATA=/home/tetsuya/development/zircon/Debug/Client/Data
WEB=/home/tetsuya/development/zircon/Debug/Client/WebData

# 1) 全量转 Interface.Zl (含 q90 有损对照统计)
$PY decode_zl_webp.py $DATA/Interface.Zl --out $WEB/interface --lossy-check

# 2) 大库均匀抽样 40 帧估算 (不落盘到 WebData)
$PY decode_zl_webp.py $DATA/Interface1c.Zl --out /tmp/webres-est/interface1c \
    --sample 40 --lossy-check

# 3) 帧范围
$PY decode_zl_webp.py $DATA/Interface.Zl --out DIR --start 100 --end 200

# 4) 启动按需加载服务 (:8821)
$PY serve.py                       # 或 WEBRES_ROOT=$WEB $PY serve.py
```

### decode_zl_webp.py 参数

`--out DIR` (必填) 输出目录；`--start/--end N` 帧范围 (含端点)；
`--sample N` 从选中帧均匀抽样 N 帧；`--lossy-check` 每帧额外算 quality=90 有损字节数 (仅统计);
`--webp-method 0-6` WebP 压缩 effort (默认 4)。

### serve.py 路由

| 路由 | 说明 |
|---|---|
| `GET /res/interface/manifest.json` | 清单 (帧号→文件/宽/高/offset_x/offset_y/codec/webp_bytes) |
| `GET /res/interface/{frame:int}.webp` | 单帧 WebP, `image/webp` |

路由对任意 `{lib}` 子目录通用 (如再转出 `GameInter` 后同样可 `/res/GameInter/...`)。

## 验证

```bash
curl -s http://127.0.0.1:8821/res/interface/manifest.json | head -c 400
curl -s -o /dev/null -w "%{http_code} %{content_type}\n" http://127.0.0.1:8821/res/interface/310.webp
```

## 重跑

```bash
rm -rf $WEB/interface && \
$PY decode_zl_webp.py $DATA/Interface.Zl --out $WEB/interface --lossy-check
```

数据结论见 `ESTIMATE.md`: Interface.Zl 4.71 MB → 2.05 MB lossless (2.29×);
Interface1c.Zl 118.7 MB 外推 ≈15–24 MB; Sound wav→OGG 实测 9.86:1。
