#!/usr/bin/env python3
"""Render DSEG7 digit bitmaps for the CasioMax watch face.

Three sizes:
  - Large (72pt): main time digits 0-9 + colon → timeLg_*.png
  - Medium (28pt): world time / date digits 0-9 + colon → timeMd_*.png
  - Small (18pt): data row digits 0-9 + comma → dataSm_*.png

Colors: dark LCD segments on transparent bg (the LCD green panel is drawn
procedurally by View.mc, not baked into the digit PNGs).

Active: near-black #1A1A1A segments
AOD:    dim green #3A5A2A segments on black (no LCD panel)
"""
import pathlib, sys
from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
PROJECT = HERE.parent
FONT_PATH = str(HERE / "DSEG7Classic-Bold.ttf")
OUT_DIR = str(PROJECT / "resources" / "drawables")

# LCD segment colors
ACTIVE_COLOR = (26, 26, 26, 255)       # #1A1A1A — dark segments on green LCD
AOD_COLOR    = (58, 90, 42, 255)        # #3A5A2A — dim green segments on black

SIZES = [
    # (prefix, font_size, canvas_w, canvas_h, chars, extra_pad)
    ("timeLg", 72, 52, 90, "0123456789", 0),
    ("timeLgColon", 72, 26, 90, ":", 0),
    ("timeMd", 28, 22, 38, "0123456789", 0),
    ("timeMdColon", 28, 12, 38, ":", 0),
    ("dataSm", 18, 16, 26, "0123456789,.", 0),
]

def render_char(text, font, canvas_w, canvas_h, color):
    img = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (canvas_w - tw) // 2 - bbox[0]
    y = (canvas_h - th) // 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=color)
    return img

for prefix, font_size, cw, ch, chars, _ in SIZES:
    font = ImageFont.truetype(FONT_PATH, font_size)
    for c in chars:
        # Sanitize filename for colon/period/comma
        safe = c
        if c == ":": safe = "colon"
        elif c == ",": safe = "comma"
        elif c == ".": safe = "period"

        # Active
        img = render_char(c, font, cw, ch, ACTIVE_COLOR)
        img.save(f"{OUT_DIR}/{prefix}_{safe}.png")

        # AOD
        img_aod = render_char(c, font, cw, ch, AOD_COLOR)
        img_aod.save(f"{OUT_DIR}/{prefix}_{safe}_aod.png")

    print(f"  {prefix}: {len(chars)} chars × 2 modes = {len(chars)*2} files, canvas {cw}×{ch}")

print("done")
