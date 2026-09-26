import json
import re
import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(REPO)
import sys
sys.path.insert(0, os.path.join(REPO, 'Tools', 'source-read'))
import read_src  # noqa: E402

# 原版帧元数据
d = json.load(open('docs/research/ei-ui-layout/gameinter-frame-metadata.json'))
orig = {int(k) for k in d['frames']}
print('原版 GameInter 帧数上限:', d['library_count'], ' 元数据已详查帧:', len(orig))

# 源码引用帧号
SRC = 'reference/mir3-source'
RE_SETS = re.compile(r"SetImgIndex\s*\(\s*g_WGameInter\w*\s*,\s*(\d+)\s*\)")
RE_IDX = re.compile(r"g_WGameInter\w*\.(?:Images|GetCachedImage)\s*\[?\s*(\d+)")

src_frames = set()
for rel in ('Source/Client/FState.pas', 'Source/Client/ClMain.pas',
            'Source/Client/PlayScn.pas', 'Source/Client/Actor.pas'):
    p = os.path.join(SRC, rel)
    if not os.path.exists(p):
        continue
    text, _ = read_src.read_text(p)
    for m in RE_SETS.finditer(text):
        src_frames.add(int(m.group(1)))
    for m in RE_IDX.finditer(text):
        src_frames.add(int(m.group(1)))

print('源码引用唯一帧号:', len(src_frames))
print('范围:', min(src_frames), '-', max(src_frames))

in_range = sorted(f for f in src_frames if f <= 1102)
out_range = sorted(f for f in src_frames if f > 1102)
print()
print('在原版 0-1102 范围内:', len(in_range), in_range)
print()
print('超出原版范围:', len(out_range))
print(out_range)
print()
print('其中被原版元数据详查过的:', sorted(set(in_range) & orig))
