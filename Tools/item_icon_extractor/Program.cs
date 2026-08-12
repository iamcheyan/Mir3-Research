using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using BCnEncoder.Decoder;
using BCnEncoder.Shared;

class ItemIconExtractor
{
    // ZL2 容器条目
    class Entry { public int Id; public int Usize; public int Csize; public long Offset; public int Comp; public int Codec; }
    class Hdr { public int Position; public int Width; public int Height; public int OffsetX; public int OffsetY; public int Codec; public int StoredSize; }

    static Dictionary<int, Entry> ParseIndex(byte[] data, int idxOff, int idxSize)
    {
        var entries = new Dictionary<int, Entry>();
        int pos = idxOff + 4;
        int end = idxOff + idxSize;
        while (pos + 23 <= end)
        {
            var e = new Entry
            {
                Id = BitConverter.ToInt32(data, pos + 1),
                Usize = BitConverter.ToInt32(data, pos + 5),
                Csize = BitConverter.ToInt32(data, pos + 9),
                Offset = BitConverter.ToInt64(data, pos + 13),
                Comp = data[pos + 21],
                Codec = data[pos + 22]
            };
            entries[e.Id] = e;
            pos += 23;
        }
        return entries;
    }

    static Dictionary<int, Hdr> ParseMeta(byte[] data, int metaOff, int metaSize)
    {
        var hdrs = new Dictionary<int, Hdr>();
        int pos = metaOff + 16; // version(4)+count(4)+atlasGroup(4)+atlasPageSize(4)
        int end = metaOff + metaSize;
        int idx = 0;
        while (pos < end)
        {
            if (data[pos] == 0) { pos++; idx++; continue; }
            // MirImage v2 metadata: Position(4) W(2) H(2) OffX(2) OffY(2) ShadowType(1) ShW(2) ShH(2) ShX(2) ShY(2) OvW(2) OvH(2) AtlasPage(4) SrcRect(16) VisRect(16) codecs(3) prefs(3) StoredImage(4) Bc7(4) Fallback(4) ...
            var h = new Hdr
            {
                Position = BitConverter.ToInt32(data, pos + 1),
                Width = BitConverter.ToInt16(data, pos + 5),
                Height = BitConverter.ToInt16(data, pos + 7),
                OffsetX = BitConverter.ToInt16(data, pos + 9),
                OffsetY = BitConverter.ToInt16(data, pos + 11),
            };
            // codecs at: after 24+4+16+16 = 60
            int codecPos = pos + 1 + 24 + 4 + 16 + 16;
            if (codecPos + 1 < end) h.Codec = data[codecPos];
            // StoredImageDataSize at codecPos+3+3 = +6
            int sizePos = codecPos + 3 + 3;
            if (sizePos + 4 <= end) h.StoredSize = BitConverter.ToInt32(data, sizePos);
            hdrs[idx] = h;
            pos += 1; // boolean byte consumed
            // 实际 MirImage 在 v2 里元数据长度 = 25 + 62 = 87? 尝试按 header 长度推进
            pos += 0; // 我们用 header 推进
            // MirImage v2: 元数据从 Position 开始 = 4+2+2+2+2+1+2+2+2+2+2+2+4+16+16+3+3+4+4+4 = 79? 保守用 87
            pos += 86;
            idx++;
        }
        return hdrs;
    }

    static byte[] DecodeBc7(byte[] data, int w, int h)
    {
        var decoder = new BcDecoder();
        int bytesPerBlock = 16;
        int ceilBytes = ((w + 3) / 4) * ((h + 3) / 4) * bytesPerBlock;
        if (data.Length < ceilBytes)
        {
            var padded = new byte[ceilBytes];
            Array.Copy(data, padded, data.Length);
            data = padded;
        }
        var pixels = decoder.DecodeRaw(data, w, h, CompressionFormat.Bc7);
        byte[] result = new byte[w * h * 4];
        for (int i = 0; i < pixels.Length && i * 4 + 3 < result.Length; i++)
        {
            result[i * 4] = pixels[i].b;
            result[i * 4 + 1] = pixels[i].g;
            result[i * 4 + 2] = pixels[i].r;
            result[i * 4 + 3] = pixels[i].a;
        }
        return result;
    }

    static void Main(string[] args)
    {
        string libPath = "/home/tetsuya/development/zircon/Debug/Client/Data/Inventory.Zl";
        string outDir = "/tmp/item_icons";
        Directory.CreateDirectory(outDir);

        byte[] data = File.ReadAllBytes(libPath);
        // 头部: 签名3 + ver(4) + imgCount(4) + atlas(4) + byte + flags(1) + short(2) = 19
        long metaOffL = BitConverter.ToInt64(data, 19);
        int metaOff = (int)metaOffL;
        int metaSize = BitConverter.ToInt32(data, 27);
        long idxOffL = BitConverter.ToInt64(data, 31);
        int idxOff = (int)idxOffL;
        int idxSize = BitConverter.ToInt32(data, 39);

        var entries = ParseIndex(data, idxOff, idxSize);
        var hdrs = ParseMeta(data, metaOff, metaSize);
        Console.WriteLine($"Entries: {entries.Count}, Headers: {hdrs.Count}");

        int ok = 0, fail = 0;
        foreach (var kv in hdrs)
        {
            var h = kv.Value;
            if (h.Width <= 0 || h.Height <= 0) continue;
            if (!entries.TryGetValue(h.Position, out var e)) continue;
            byte[] raw = new byte[e.Csize];
            Array.Copy(data, e.Offset, raw, 0, e.Csize);
            if (e.Comp != 0)
            {
                using var ms = new MemoryStream(raw);
                using var ds = new DeflateStream(ms, CompressionMode.Decompress);
                using var outMs = new MemoryStream();
                ds.CopyTo(outMs);
                raw = outMs.ToArray();
            }
            try
            {
                byte[] px = DecodeBc7(raw, h.Width, h.Height);
                // 用 Position 命名（= 物品 Image 值）而非循环 idx
                WriteBmp(Path.Combine(outDir, $"{h.Position}.bmp"), px, h.Width, h.Height);
                ok++;
            }
            catch { fail++; }
        }
        Console.WriteLine($"OK: {ok}, Fail: {fail}");
    }

    static void WriteBmp(string path, byte[] rgba, int w, int h)
    {
        int rowSize = (w * 3 + 3) & ~3;
        int dataSize = rowSize * h;
        using var fs = new FileStream(path, FileMode.Create);
        using var bw = new BinaryWriter(fs);
        bw.Write((byte)'B'); bw.Write((byte)'M');
        bw.Write(54 + dataSize);
        bw.Write(0); bw.Write(54);
        bw.Write(40); bw.Write(w); bw.Write(h);
        bw.Write((short)1); bw.Write((short)24);
        bw.Write(0); bw.Write(dataSize);
        bw.Write(2835); bw.Write(2835);
        bw.Write(0); bw.Write(0);
        for (int y = h - 1; y >= 0; y--)
        {
            for (int x = 0; x < w; x++)
            {
                int i = (y * w + x) * 4;
                bw.Write(rgba[i + 2]); bw.Write(rgba[i + 1]); bw.Write(rgba[i]);
            }
            for (int p = w * 3; p < rowSize; p++) bw.Write((byte)0);
        }
    }
}
