import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
base = os.path.join(REPO, 'reference/mir3-source/Mud3-Config')

for env in ('Envir', 'Envir3'):
    root = os.path.join(base, env)
    files = []
    total = 0
    empty = []
    for r, dirs, fs in os.walk(root):
        for f in fs:
            p = os.path.join(r, f)
            sz = os.path.getsize(p)
            rel = os.path.relpath(p, root)
            files.append((rel, sz))
            total += sz
            if sz == 0:
                empty.append(rel)
    print('=== %s: %d 文件, %d 字节, 空文件 %d ===' % (env, len(files), total, len(empty)))
    files.sort(key=lambda x: -x[1])
    print('  最大 10:')
    for rel, sz in files[:10]:
        print('    %8d  %s' % (sz, rel))
    if empty:
        print('  空文件 (%d):' % len(empty))
        for e in sorted(empty)[:30]:
            print('    %s' % e)
    print()

# 两目录同名文件对照
def names(env):
    root = os.path.join(base, env)
    out = {}
    for r, dirs, fs in os.walk(root):
        for f in fs:
            rel = os.path.relpath(os.path.join(r, f), root)
            out[rel.lower()] = os.path.getsize(os.path.join(r, f))
    return out

e1, e3 = names('Envir'), names('Envir3')
both = sorted(set(e1) & set(e3))
print('=== 同名文件对照 (%d 个) ===' % len(both))
print('%-28s %10s %10s' % ('文件', 'Envir', 'Envir3'))
for n in both:
    mark = ''
    if e1[n] == 0 and e3[n] > 0:
        mark = '  ← Envir 为空'
    elif e3[n] == 0 and e1[n] > 0:
        mark = '  ← Envir3 为空'
    print('%-28s %10d %10d%s' % (n, e1[n], e3[n], mark))

print()
print('=== 仅 Envir3 有 ===')
for n in sorted(set(e3) - set(e1))[:15]:
    print('  %8d  %s' % (e3[n], n))
print('  ... 共 %d' % len(set(e3) - set(e1)))
