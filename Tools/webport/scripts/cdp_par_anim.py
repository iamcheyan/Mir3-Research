#!/usr/bin/env python3
# cdp_par_anim.py — par-anim GM 实测驱动 (CDP over websockets)
# 打开 8823?demo=1 → 等完整场景链 Login→Select→Game → 逐技能实测 → 截图
# 产物: docs/webport/parity/par-anim/gm-anim-results.json + gm-*.png
import asyncio, json, base64, pathlib, urllib.request
import websockets

PORT = 9461
SHOT_DIR = pathlib.Path('docs/webport/parity/par-anim')
SHOT_DIR.mkdir(parents=True, exist_ok=True)

class CDP:
    def __init__(self, ws): self.ws = ws; self._id = 0; self._fut = {}
    async def send(self, method, **params):
        self._id += 1; mid = self._id
        fut = asyncio.get_running_loop().create_future(); self._fut[mid] = fut
        await self.ws.send(json.dumps({'id': mid, 'method': method, 'params': params}))
        return await asyncio.wait_for(fut, timeout=20)
    async def recv_loop(self):
        try:
            async for raw in self.ws:
                msg = json.loads(raw)
                if 'id' in msg and msg['id'] in self._fut:
                    self._fut.pop(msg['id']).set_result(msg)
        except websockets.ConnectionClosed:
            pass
    async def eval(self, expr, await_promise=False):
        r = await self.send('Runtime.evaluate', expression=expr, awaitPromise=await_promise, returnByValue=True)
        if 'exceptionDetails' in r:
            raise RuntimeError(r['exceptionDetails'].get('text') + str(r['exceptionDetails'].get('exception', {})))
        return r.get('result', {}).get('result', {}).get('value')

async def fetch_list():
    with urllib.request.urlopen(f'http://127.0.0.1:{PORT}/json/list') as r:
        return json.loads(r.read())

async def scene_of(cdp):
    return await cdp.eval("window.__WEBPORT?.current?.constructor?.name ?? 'none'")

async def main():
    pages = await fetch_list()
    page = next(p for p in pages if p['type'] == 'page')
    async with websockets.connect(page['webSocketDebuggerUrl'], max_size=64*1024*1024) as ws:
        cdp = CDP(ws)
        rt = asyncio.get_running_loop().create_task(cdp.recv_loop())
        await cdp.send('Page.enable')
        await cdp.send('Runtime.enable')

        await cdp.send('Page.navigate', url='http://127.0.0.1:8823/?demo=1&t=' + str(__import__('time').time()))
        # 等文档真正重载: __WEBPORT 消失再出现
        await asyncio.sleep(2)
        attempts = 0
        for _ in range(90):
            s = await scene_of(cdp)
            if s in ('GameScene',): break
            if s == 'none':
                await asyncio.sleep(1); continue
            # LoginScene: GoodVersion 后点登录; AlreadyLoggedIn(同 IP 占用) 时首点踢旧连接,
            # 次点成功 (SEnvir.cs:3381-3386) — 最多 3 轮, 每轮间隔 6s
            if s == 'LoginScene':
                logs = await cdp.eval("JSON.stringify((window.__WEBPORT?.log??[]).slice(-1))")
                if 'GoodVersion' in (logs or ''):
                    enabled = await cdp.eval("window.__WEBPORT?.current?.btnLogin?.enabled === true")
                    if enabled and attempts < 3:
                        attempts += 1
                        print(f'登录尝试 #{attempts}')
                        await cdp.eval("window.__WEBPORT.current.btnLogin.onClick()")
                        await asyncio.sleep(6)
                        continue
            await asyncio.sleep(1)
        s = await scene_of(cdp)
        if s != 'GameScene':
            logs = await cdp.eval("JSON.stringify((window.__WEBPORT?.log??[]).slice(-6))")
            print(f'FAIL: scene={s}; logs={logs}'); rt.cancel(); return

        # 等 world.player 就绪 (进图)
        ready = False
        for _ in range(30):
            if await cdp.eval("!!window.__WEBPORT?.current?.world?.player?.animState"):
                ready = True; break
            await asyncio.sleep(1)
        if not ready:
            print('FAIL: world.player.animState 未就绪 (旧 JS 缓存?)'); rt.cancel(); return

        await cdp.eval("globalThis.g = window.__WEBPORT.current")
        state = await cdp.eval("JSON.stringify({x:g.world.player.x, y:g.world.player.y, anim:g.world.player.animName, cls:g.world.player.class, weapon:g.world.player.weapon, objs:g.world.objects.size})")
        print('STATE:', state)

        skills = {
            'FireBall-201-C1': 201, 'Heal-300-C2': 300, 'PoisonousCloud-404-C14': 404,
            'ThunderKick-324-C7': 324, 'ElementalHurricane-232-Channelling': 232,
            'DragonRepulse-430-DRStart': 430, 'Defiance-111-C15': 111,
            'FlashOfLight-434-C10': 434, 'Cloak-406-C9-Creep': 406,
        }
        results = {}
        for name, magic in skills.items():
            await cdp.eval(f"g.world.castMagic({magic}, null)")
            await asyncio.sleep(0.4)
            snap = await cdp.eval("JSON.stringify({anim:g.world.player.animName, stanceLeftSec:Math.round((g.world.player.animState.stanceTimeMs-performance.now())/1000), buffs:[...g.world.player.animState.buffs], drawWeapon:g.world.player.animState.drawWeapon})")
            results[name] = json.loads(snap)
            try:
                shot = await cdp.send('Page.captureScreenshot', format='png')
                (SHOT_DIR / f'gm-{name}.png').write_bytes(base64.b64decode(shot['result']['data']))
            except Exception as ex:
                print(f'  (截图失败: {ex})')

        await cdp.eval("g.world.player.playCombat(0)")
        await asyncio.sleep(0.3)
        atk = await cdp.eval("JSON.stringify({anim:g.world.player.animName, stanceMs:Math.round(g.world.player.animState.stanceTimeMs-performance.now())})")
        print('Attack:', atk)

        await cdp.eval("g.world.player.playCombat(102)")   # Slaying
        await asyncio.sleep(0.3)
        atk2 = await cdp.eval("JSON.stringify(g.world.player.animName)")
        print('Attack/Slaying:', atk2)

        try:
            shot = await cdp.send('Page.captureScreenshot', format='png')
            (SHOT_DIR / 'gm-final.png').write_bytes(base64.b64decode(shot['result']['data']))
        except Exception as ex:
            print(f'(final 截图失败: {ex})')
        (SHOT_DIR / 'gm-anim-results.json').write_text(json.dumps(
            {'state': json.loads(state), 'skills': results,
             'attack': json.loads(atk), 'attackSlaying': json.loads(atk2)},
            ensure_ascii=False, indent=2))
        print('saved:', SHOT_DIR / 'gm-anim-results.json')
        rt.cancel()

asyncio.run(main())
