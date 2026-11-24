#!/usr/bin/env python3
"""Render terminal text as a dark-theme PNG.   render-frame.py <input.txt> <output.png> [title]

Used for the contest timeline: the text comes from `rex capture` of the contest tab only, so the picture
holds nothing else from the desktop.
"""
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/Menlo.ttc"
SIZE, PAD, MAX_COLS, MAX_ROWS = 15, 16, 130, 45


def main():
    if len(sys.argv) < 3:
        print("usage: render-frame.py <input.txt> <output.png> [title]", file=sys.stderr)
        return 1
    lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().rstrip("\n").split("\n")[-MAX_ROWS:]
    lines = [ln.expandtabs(4)[:MAX_COLS] for ln in lines]
    title = sys.argv[3] if len(sys.argv) > 3 else ""
    font = ImageFont.truetype(FONT, SIZE)
    cw = font.getlength("M")
    lh = SIZE + 5
    width = int(PAD * 2 + cw * MAX_COLS)
    head = 34
    img = Image.new("RGB", (width, head + PAD * 2 + lh * max(len(lines), 8)), "#15171c")
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, width, head], fill="#22252d")
    for i, c in enumerate(("#ff5f57", "#febc2e", "#28c840")):
        d.ellipse([14 + i * 22, 11, 26 + i * 22, 23], fill=c)
    d.text((width // 2 - font.getlength(title) / 2, 8), title, font=font, fill="#9aa0ab")
    for i, ln in enumerate(lines):
        d.text((PAD, head + PAD + i * lh), ln, font=font, fill="#d7dae0")
    img.save(sys.argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main())
