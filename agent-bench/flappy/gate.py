"""Flappy Bird completion gate. Prints what failed and exits 1, or prints "gate passed ..." and exits 0.

    uv run --no-project --with playwright python gate.py <project-dir> <out-dir>

Opens <project-dir>/index.html in installed Google Chrome with an iPhone-sized touch viewport and checks, in order:
self-contained, no console errors, mobile viewport and no scrolling, the window.game test hook, tap starts play,
the bird falls to game over untouched, a tap restarts, and a simple bot that taps when the bird is below the gap
passes at least one pipe. GATE_QUERY (env) is appended to the page URL; the manual validation uses it.
"""
import json
import os
import re
import sys
import time
from pathlib import Path

from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import sync_playwright

W, H = 390, 844


def fail(msg: str) -> None:
    print(msg)
    sys.exit(1)


def state(page) -> dict:
    return page.evaluate(
        "() => window.game ? JSON.parse(JSON.stringify({state: window.game.state, score: window.game.score,"
        " bird: window.game.bird, pipes: window.game.pipes})) : null"
    )


def shot(page, path: Path) -> bytes:
    return page.screenshot(path=str(path))


def colors(png: bytes) -> int:
    # Cheap proxy: distinct byte values in a sample of the compressed PNG; a flat image compresses to almost nothing.
    return len(set(png[::97]))


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: gate.py <project-dir> <out-dir>")
    proj, out = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    index = proj / "index.html"
    if not index.is_file():
        fail("There is no index.html in the project root. Create the game as a single index.html file.")
    html = index.read_text(errors="replace")
    ext = re.findall(r"""(?:src|href)\s*=\s*["']\s*(?:https?:)?//[^"']+|@import\s+url\(\s*["']?(?:https?:)?//|url\(\s*["']?https?://""", html)
    if ext:
        fail("index.html makes external requests (" + ext[0].strip()[:80] + "). Inline everything; no CDN, fonts or images by URL.")

    errors: list[str] = []
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch(channel="chrome", headless=True)
        except PlaywrightError as exc:
            fail("internal: could not start Google Chrome: " + str(exc).splitlines()[0])
        ctx = browser.new_context(viewport={"width": W, "height": H}, device_scale_factor=3, is_mobile=True, has_touch=True)
        page = ctx.new_page()
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        page.goto(index.as_uri() + os.environ.get("GATE_QUERY", ""))
        page.wait_for_timeout(1500)
        if errors:
            fail("The page logged JavaScript errors on load:\n" + "\n".join(errors[:5]))

        meta = page.evaluate("() => (document.querySelector('meta[name=viewport]')||{}).content || ''")
        if "width=device-width" not in meta.replace(" ", ""):
            fail('Add <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"> so phones lay the page out at device width.')
        scroll = page.evaluate("() => [document.documentElement.scrollWidth, document.documentElement.scrollHeight, innerWidth, innerHeight]")
        if scroll[0] > scroll[2] + 1 or scroll[1] > scroll[3] + 1:
            fail(f"The page scrolls: content is {scroll[0]}x{scroll[1]} in a {scroll[2]}x{scroll[3]} viewport. Make the game exactly fill the screen with overflow hidden.")
        big = page.evaluate(f"() => [...document.querySelectorAll('canvas,#game,main')].some(e => e.getBoundingClientRect().width >= {W}*0.95 && e.getBoundingClientRect().height >= {H}*0.7)")
        if not big:
            fail("No canvas (or #game/main element) fills at least 95% of the width and 70% of the height. The game must fill the phone screen.")

        g = state(page)
        if g is None:
            fail("window.game is missing. Expose window.game = { state, score, bird, pipes } as the prompt describes.")
        if g["state"] != "ready" or not isinstance(g["score"], (int, float)) or not isinstance(g["bird"], dict):
            fail(f"On load window.game.state must be 'ready' with a numeric score and a bird object; got {json.dumps(g)[:200]}")
        a = shot(page, out / "ready.png")
        if colors(a) < 40:
            fail("The ready screen looks blank or a single flat colour. Draw the sky, ground and bird.")

        page.touchscreen.tap(W // 2, H // 2)
        page.wait_for_timeout(600)
        g = state(page)
        if g["state"] != "playing":
            fail(f"A tap on the ready screen must start play (window.game.state 'playing'); state is '{g['state']}'. Handle touchstart or pointerdown on the page.")
        b1 = shot(page, out / "playing-1.png")
        page.wait_for_timeout(250)
        b2 = shot(page, out / "playing-2.png")
        if b1 == b2:
            fail("Two frames 250 ms apart are identical; the game is not animating.")

        deadline = time.time() + 15
        while time.time() < deadline and state(page)["state"] == "playing":
            page.wait_for_timeout(200)
        g = state(page)
        if g["state"] != "over":
            fail(f"A bird that is never tapped must hit the ground and end the game within 15 s; state is still '{g['state']}'.")
        shot(page, out / "over.png")
        page.wait_for_timeout(700)
        page.touchscreen.tap(W // 2, H // 2)
        page.wait_for_timeout(600)
        g = state(page)
        if g["state"] == "over":
            page.touchscreen.tap(W // 2, H // 2)
            page.wait_for_timeout(600)
            g = state(page)
        if g["state"] not in ("ready", "playing"):
            fail(f"A tap on the game-over screen must start a new game; state stayed '{g['state']}'.")

        # The bot: tap when the bird is below the middle of the next gap (or the screen), otherwise wait.
        best = 0
        for attempt in range(3):
            if state(page)["state"] == "over":
                page.wait_for_timeout(700)
            end = time.time() + 40
            while time.time() < end:
                g = state(page)
                if g["state"] == "over":
                    break
                if g["state"] == "ready":
                    page.touchscreen.tap(W // 2, H // 2)
                    page.wait_for_timeout(120)
                    continue
                bird = g["bird"]
                ahead = [q for q in g["pipes"] if q["x"] + q["width"] > bird["x"] - bird["r"]]
                ahead.sort(key=lambda q: q["x"])
                target = (ahead[0]["gapTop"] + ahead[0]["gapBottom"]) / 2 if ahead else H * 0.45
                if bird["y"] > target + 12:
                    page.touchscreen.tap(W // 2, H // 2)
                page.wait_for_timeout(40)
            best = max(best, int(state(page)["score"]))
            if best >= 1:
                break
        shot(page, out / "bot.png")
        browser.close()
    if best < 1:
        fail("A bot that taps whenever the bird is below the middle of the next gap never passed a pipe in 3 tries. Check that pipes have a gap the bird can fit and reach, that a tap lifts the bird, and that window.game.pipes and window.game.bird match what is drawn.")
    print(f"gate passed: mobile viewport {W}x{H}, hook ok, restart ok, bot scored {best}")


if __name__ == "__main__":
    main()
