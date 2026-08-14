// skin.js — MirSkin 的 Web 等价物 (GodotClient/Controls/MirSkin.cs)
// 贴图: /res/sprites/{lib}/{n}.webp (存在即服务, 缺失时 serve.py 按需从 .Zl 抽取)
// 元数据: /res/sprites/{lib}/manifest.json → {idx: [w, h, ox, oy]}

const manifests = new Map();   // lib → {idx:[w,h,ox,oy]}
const frames = new Map();      // lib:idx → {url,w,h,ox,oy}

async function manifest(lib) {
  if (manifests.has(lib)) return manifests.get(lib);
  const m = await fetch(`/res/sprites/${lib}/manifest.json`).then(r => r.ok ? r.json() : null).catch(() => null);
  manifests.set(lib, m ?? {});
  return manifests.get(lib);
}

export const skin = {
  // MirSkin.GetTexture + GetSize + GetOffset 合一; 缺图返回 null (控件静默跳过)
  async frame(lib, idx) {
    const key = `${lib}:${idx}`;
    if (frames.has(key)) return frames.get(key);
    const m = await manifest(lib);
    const meta = m[idx];
    if (!meta) { frames.set(key, null); return null; }
    const f = {
      url: `/res/sprites/${lib}/${idx}.webp`,
      w: meta[0], h: meta[1], ox: meta[2], oy: meta[3],
    };
    frames.set(key, f);
    return f;
  },
  // 同步取已缓存的帧 (DXAnimatedControl 连续换帧用)
  cached(lib, idx) { return frames.get(`${lib}:${idx}`) ?? null; },
};
