"""Vygeneruje launcher ikonu pro MFC Vysocina app — cerveny stit s mecem."""
from PIL import Image, ImageDraw
from pathlib import Path
import sys

OUT_DIR = Path(r"C:\Users\H1r0sh1ma\Desktop\mfc-vysocina-app\mfc_app\assets")
OUT_DIR.mkdir(exist_ok=True)

W = 1024
RED = (211, 47, 47)
WHITE = (255, 255, 255)


def draw_shield_and_sword(d, cx, cy, scale, shield_color, accent_color):
    """Nakresli stit + mec uvnitr.

    cx, cy: stred
    scale: 0.0..1.0
    shield_color: barva stitu
    accent_color: barva sword/akcent
    """
    sw, sh = int(480 * scale), int(560 * scale)
    left = cx - sw // 2
    right = cx + sw // 2
    top = cy - sh // 2 + int(60 * scale)
    bottom = cy + sh // 2

    # Stit polygon
    shield = [
        (left, top),
        (right, top),
        (right, top + int(sh * 0.55)),
        (cx, bottom),
        (left, top + int(sh * 0.55)),
    ]
    d.polygon(shield, fill=shield_color)

    # Zaobleny vrch
    rad = int(60 * scale)
    d.pieslice([left, top - rad, left + rad + 20, top + 20], 180, 270, fill=shield_color)
    d.pieslice([right - rad - 20, top - rad, right, top + 20], 270, 360, fill=shield_color)
    d.rectangle([left + 40, top - rad, right - 40, top + 20], fill=shield_color)

    # Mec (svisle)
    sword_x = cx
    sword_top = top + int(80 * scale)
    sword_bottom = bottom - int(70 * scale)
    blade_w = max(1, int(18 * scale))
    d.rectangle([sword_x - blade_w, sword_top, sword_x + blade_w, sword_bottom], fill=accent_color)

    # Krizovka
    crg_y = sword_top + int(90 * scale)
    crg_w = int(130 * scale)
    crg_h = max(1, int(30 * scale))
    d.rectangle([sword_x - crg_w, crg_y, sword_x + crg_w, crg_y + crg_h], fill=accent_color)

    # Hlavice (kotouc nahore)
    pommel_r = int(30 * scale)
    d.ellipse([sword_x - pommel_r, sword_top - pommel_r, sword_x + pommel_r, sword_top + pommel_r], fill=accent_color)

    # Hrot dole
    tip = int(50 * scale)
    d.polygon([
        (sword_x - blade_w, sword_bottom),
        (sword_x + blade_w, sword_bottom),
        (sword_x, sword_bottom + tip),
    ], fill=accent_color)


# 1) Plny launcher icon (cerveny BG + bily stit + cerveny mec)
img = Image.new('RGBA', (W, W), RED)
d = ImageDraw.Draw(img)
draw_shield_and_sword(d, W // 2, W // 2 - 30, 1.0, WHITE, RED)
launcher = OUT_DIR / "icon.png"
img.save(launcher, "PNG")
print(f"OK {launcher}")

# 2) Foreground (pruhledne pozadi) pro Android adaptive icon
# Bezpecna zona Android adaptive icons je vnitrnich ~432px z 1024px
fg = Image.new('RGBA', (W, W), (0, 0, 0, 0))
fd = ImageDraw.Draw(fg)
draw_shield_and_sword(fd, W // 2, W // 2, 0.55, WHITE, RED)
fg_path = OUT_DIR / "icon_foreground.png"
fg.save(fg_path, "PNG")
print(f"OK {fg_path}")

print("Hotovo.")
