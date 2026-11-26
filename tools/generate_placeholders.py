#!/usr/bin/env python3
"""Generate CSP-replaceable procedural placeholder art for Tea in the Hegemony.

Naming convention (see assets/ASSETS.md):
  assets/portraits/{character_id}_{expression}.png
  assets/silhouettes/{character_id}_sil.png
  assets/backgrounds/{location_id}_bg.png
  assets/ui/{element_id}.png
"""

from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"

# Palette — ink navy / brass / jade / ivory / vermillion (not purple, not cream+terracotta)
INK = (11, 18, 32)
SALON = (26, 35, 50)
BRASS = (196, 165, 116)
JADE = (91, 138, 122)
IVORY = (232, 224, 212)
VERMIL = (196, 92, 70)
PAPER = (212, 207, 196)
SLATE = (37, 48, 64)
AMBER = (210, 170, 80)
WINE = (90, 40, 48)
TEAL_MIST = (60, 90, 100)


CHARS = {
    "cassian_vale": {
        "skin": (92, 62, 48),
        "hair": (18, 14, 12),
        "eyes": (28, 22, 18),
        "accent": BRASS,
        "silhouette": "lean_coat",
        "initials": "CV",
    },
    "maris_quell": {
        "skin": (210, 175, 150),
        "hair": (55, 38, 28),
        "eyes": (70, 95, 90),
        "accent": JADE,
        "silhouette": "poised",
        "initials": "MQ",
    },
    "wren_halden": {
        "skin": (185, 150, 130),
        "hair": (40, 45, 50),
        "eyes": (90, 70, 55),
        "accent": AMBER,
        "silhouette": "handler",
        "initials": "WH",
    },
    "edrin_voss": {
        "skin": (200, 170, 145),
        "hair": (70, 55, 40),
        "eyes": (50, 55, 70),
        "accent": WINE,
        "silhouette": "host",
        "initials": "EV",
    },
    "taly_renn": {
        "skin": (175, 140, 115),
        "hair": (30, 25, 22),
        "eyes": (80, 60, 45),
        "accent": (140, 110, 90),
        "silhouette": "observer",
        "initials": "TR",
    },
    "sera_kade": {
        "skin": (195, 160, 140),
        "hair": (120, 40, 45),
        "eyes": (55, 70, 85),
        "accent": VERMIL,
        "silhouette": "rival",
        "initials": "SK",
    },
    "pim_orel": {
        "skin": (205, 180, 155),
        "hair": (90, 75, 50),
        "eyes": (60, 80, 70),
        "accent": (160, 140, 100),
        "silhouette": "disaster",
        "initials": "PO",
    },
    "clerk_moth": {
        "skin": (190, 175, 160),
        "hair": (100, 100, 105),
        "eyes": (70, 70, 75),
        "accent": SLATE,
        "silhouette": "bureaucrat",
        "initials": "CM",
    },
}

EXPRESSIONS = {
    "neutral": {"brow": 0, "mouth": 0, "eye_open": 1.0},
    "amused": {"brow": -2, "mouth": 4, "eye_open": 0.95},
    "suspicious": {"brow": 4, "mouth": -2, "eye_open": 0.85},
    "flustered": {"brow": 3, "mouth": 2, "eye_open": 1.1},
    "cold": {"brow": -1, "mouth": -3, "eye_open": 0.9},
}


def ensure_dirs() -> None:
    for p in [
        ASSETS / "portraits",
        ASSETS / "silhouettes",
        ASSETS / "backgrounds",
        ASSETS / "ui",
        ASSETS / "fonts",
    ]:
        p.mkdir(parents=True, exist_ok=True)


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in [
        ASSETS / "fonts" / "Tinos-Bold.ttf",
        ASSETS / "fonts" / "Tinos-Regular.ttf",
        ASSETS / "fonts" / "PublicSans-Bold.ttf",
    ]:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def vignette(img: Image.Image, strength: float = 0.55) -> Image.Image:
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for i in range(40):
        alpha = int(strength * 255 * (i / 40) ** 1.6)
        inset = int(i * min(w, h) / 80)
        draw.ellipse(
            [inset, inset, w - inset, h - inset],
            outline=(0, 0, 0, alpha),
            width=max(2, min(w, h) // 40),
        )
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def draw_portrait(char_id: str, expression: str, size: int = 512) -> Image.Image:
    data = CHARS[char_id]
    expr = EXPRESSIONS[expression]
    img = Image.new("RGBA", (size, size), (*INK, 255))
    d = ImageDraw.Draw(img)

    # Panel frame — comic still
    margin = 18
    d.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=8,
        fill=(*SALON, 255),
        outline=(*BRASS, 220),
        width=3,
    )
    # Inner paper wash
    d.rounded_rectangle(
        [margin + 10, margin + 10, size - margin - 10, size - margin - 10],
        radius=4,
        fill=(*PAPER, 40),
    )

    cx, cy = size // 2, size // 2 + 20
    head_r = size // 5

    # Shoulders / coat silhouette
    coat = data["accent"]
    d.polygon(
        [
            (cx - head_r * 1.6, size - margin - 20),
            (cx - head_r * 0.9, cy + head_r * 0.7),
            (cx + head_r * 0.9, cy + head_r * 0.7),
            (cx + head_r * 1.6, size - margin - 20),
        ],
        fill=(*coat, 180),
    )
    d.polygon(
        [
            (cx - head_r * 1.5, size - margin - 20),
            (cx - head_r * 0.7, cy + head_r * 0.85),
            (cx + head_r * 0.7, cy + head_r * 0.85),
            (cx + head_r * 1.5, size - margin - 20),
        ],
        fill=(*INK, 200),
    )

    # Neck
    d.rectangle(
        [cx - head_r // 3, cy + head_r // 2, cx + head_r // 3, cy + head_r],
        fill=(*data["skin"], 255),
    )

    # Head
    d.ellipse(
        [cx - head_r, cy - head_r, cx + head_r, cy + head_r],
        fill=(*data["skin"], 255),
        outline=(*INK, 120),
        width=2,
    )

    # Hair mass — exaggerated silhouette
    hair = data["hair"]
    d.chord(
        [cx - head_r - 8, cy - head_r - 30, cx + head_r + 8, cy + 10],
        200,
        340,
        fill=(*hair, 255),
    )
    d.ellipse(
        [cx - head_r - 4, cy - head_r - 20, cx + head_r + 4, cy - head_r // 3],
        fill=(*hair, 255),
    )

    # Eyes — comic exaggeration
    eye_y = cy - 10 + expr["brow"]
    eye_w = int(28 * expr["eye_open"])
    eye_h = int(16 * expr["eye_open"])
    for ex in (-40, 40):
        d.ellipse(
            [cx + ex - eye_w, eye_y - eye_h, cx + ex + eye_w, eye_y + eye_h],
            fill=(IVORY[0], IVORY[1], IVORY[2], 255),
            outline=(*INK, 200),
            width=2,
        )
        pupil = 8
        d.ellipse(
            [
                cx + ex - pupil,
                eye_y - pupil + 2,
                cx + ex + pupil,
                eye_y + pupil + 2,
            ],
            fill=(*data["eyes"], 255),
        )
        # Brow
        by = eye_y - eye_h - 10 + expr["brow"]
        d.line(
            [cx + ex - 22, by, cx + ex + 22, by - expr["brow"]],
            fill=(*hair, 255),
            width=4,
        )

    # Mouth
    my = cy + 45 + expr["mouth"]
    if expr["mouth"] >= 3:
        d.arc([cx - 28, my - 18, cx + 28, my + 18], 20, 160, fill=(*INK, 255), width=3)
    elif expr["mouth"] <= -2:
        d.arc([cx - 24, my - 8, cx + 24, my + 20], 200, 340, fill=(*INK, 255), width=3)
    else:
        d.line([cx - 22, my, cx + 22, my + expr["mouth"]], fill=(*INK, 255), width=3)

    # Accent rule + initials (placeholder label for CSP swap)
    d.rectangle([margin + 16, size - 70, size - margin - 16, size - 42], fill=(*INK, 210))
    d.text(
        (margin + 24, size - 66),
        f"{data['initials']} · {expression}",
        fill=(*BRASS, 255),
        font=font(22),
    )

    # Comic speed lines (subtle)
    for i in range(6):
        ang = i * math.pi / 6
        x0 = cx + int(math.cos(ang) * (head_r + 40))
        y0 = cy + int(math.sin(ang) * (head_r + 20)) - 40
        x1 = cx + int(math.cos(ang) * (head_r + 90))
        y1 = cy + int(math.sin(ang) * (head_r + 50)) - 40
        d.line([x0, y0, x1, y1], fill=(*BRASS, 40), width=2)

    return vignette(img, 0.35)


def draw_silhouette(char_id: str, size: int = 256) -> Image.Image:
    data = CHARS[char_id]
    img = Image.new("RGBA", (size, int(size * 1.6)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = size // 2
    fill = (*INK, 230)
    accent = (*data["accent"], 255)

    # Full-body expressive silhouette
    d.ellipse([cx - 28, 20, cx + 28, 76], fill=fill)  # head
    d.polygon([(cx - 50, 70), (cx + 50, 70), (cx + 70, 200), (cx - 70, 200)], fill=fill)
    d.rectangle([cx - 22, 200, cx - 6, size + 80], fill=fill)
    d.rectangle([cx + 6, 200, cx + 22, size + 80], fill=fill)
    # Accent lapel slash
    d.polygon([(cx - 8, 90), (cx + 4, 90), (cx - 2, 160)], fill=accent)
    # Frame tick
    d.rectangle([8, 8, size - 8, 12], fill=(*BRASS, 180))
    return img


def draw_background(location_id: str, w: int = 1280, h: int = 720) -> Image.Image:
    schemes = {
        "foyer": (INK, SALON, BRASS),
        "salon": (SALON, (40, 50, 65), JADE),
        "terrace": ((20, 28, 40), TEAL_MIST, AMBER),
        "study_annex": ((18, 22, 30), WINE, BRASS),
        "cloakroom": ((22, 24, 28), SLATE, VERMIL),
        "briefing": (INK, (30, 40, 55), AMBER),
    }
    c0, c1, accent = schemes.get(location_id, (INK, SALON, BRASS))
    img = Image.new("RGB", (w, h), c0)
    d = ImageDraw.Draw(img)

    # Gradient wash
    for y in range(h):
        t = y / h
        col = tuple(int(c0[i] * (1 - t) + c1[i] * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=col)

    # Architectural verticals — upper-class space
    for x in range(80, w, 160):
        d.rectangle([x, 40, x + 6, h - 80], fill=tuple(min(255, c + 12) for c in c1))

    # Horizon / floor plane
    d.polygon([(0, h - 120), (w, h - 160), (w, h), (0, h)], fill=tuple(max(0, c - 15) for c in c0))

    # Window / panel rectangles
    for i, x in enumerate([180, 520, 860]):
        d.rectangle([x, 80, x + 200, 280], outline=accent, width=2)
        d.rectangle([x + 8, 88, x + 192, 272], fill=tuple(int(c * 0.7) for c in accent) + ())
        # Fix fill - need RGB
        d.rectangle([x + 8, 88, x + 192, 272], fill=tuple(int(a * 0.25 + c0[j] * 0.75) for j, a in enumerate(accent)))

    # Vignette-ish borders
    d.rectangle([0, 0, w - 1, h - 1], outline=BRASS, width=4)
    d.text((40, h - 60), f"LOC · {location_id.replace('_', ' ').upper()}", fill=BRASS, font=font(28))
    d.text((40, 36), "TEA IN THE HEGEMONY", fill=IVORY, font=font(22))
    return img


def draw_ui_chrome() -> None:
    # Dialogue panel texture
    panel = Image.new("RGBA", (960, 220), (*SALON, 230))
    d = ImageDraw.Draw(panel)
    d.rectangle([0, 0, 959, 219], outline=BRASS, width=2)
    d.line([(24, 40), (300, 40)], fill=BRASS, width=2)
    d.rectangle([0, 0, 8, 219], fill=JADE)
    panel.save(ASSETS / "ui" / "dialogue_panel.png")

    # Choice button
    btn = Image.new("RGBA", (640, 56), (*SLATE, 220))
    d = ImageDraw.Draw(btn)
    d.rectangle([0, 0, 639, 55], outline=BRASS, width=1)
    d.rectangle([0, 0, 4, 55], fill=JADE)
    btn.save(ASSETS / "ui" / "choice_button.png")

    # Intent chip
    chip = Image.new("RGBA", (160, 28), (*INK, 200))
    d = ImageDraw.Draw(chip)
    d.rounded_rectangle([0, 0, 159, 27], radius=2, outline=AMBER, width=1)
    chip.save(ASSETS / "ui" / "intent_chip.png")

    # Notebook page
    note = Image.new("RGBA", (720, 900), (*PAPER, 255))
    d = ImageDraw.Draw(note)
    for y in range(60, 880, 28):
        d.line([(48, y), (680, y)], fill=(180, 175, 165), width=1)
    d.rectangle([40, 20, 44, 880], fill=VERMIL)
    d.rectangle([0, 0, 719, 899], outline=BRASS, width=2)
    note.save(ASSETS / "ui" / "notebook_page.png")

    # Faculty panel
    fac = Image.new("RGBA", (320, 120), (*INK, 210))
    d = ImageDraw.Draw(fac)
    d.rectangle([0, 0, 319, 119], outline=AMBER, width=2)
    d.polygon([(0, 0), (24, 0), (0, 24)], fill=AMBER)
    fac.save(ASSETS / "ui" / "faculty_panel.png")

    # Mission stamp
    stamp = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(stamp)
    d.ellipse([8, 8, 120, 120], outline=VERMIL, width=4)
    d.text((28, 52), "OPS", fill=VERMIL, font=font(28))
    stamp.save(ASSETS / "ui" / "mission_stamp.png")

    # Logo mark
    logo = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(logo)
    d.ellipse([20, 20, 236, 236], outline=BRASS, width=4)
    d.ellipse([48, 48, 208, 208], outline=JADE, width=2)
    d.text((78, 105), "TITH", fill=IVORY, font=font(36))
    logo.save(ASSETS / "ui" / "logo_mark.png")

    # Cursor / focus frame
    focus = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(focus)
    for x0, y0, x1, y1 in [(0, 0, 16, 2), (0, 0, 2, 16), (48, 0, 64, 2), (62, 0, 64, 16),
                            (0, 62, 16, 64), (0, 48, 2, 64), (48, 62, 64, 64), (62, 48, 64, 64)]:
        d.rectangle([x0, y0, x1, y1], fill=BRASS)
    focus.save(ASSETS / "ui" / "focus_corners.png")


def main() -> None:
    ensure_dirs()
    for char_id in CHARS:
        for expression in EXPRESSIONS:
            path = ASSETS / "portraits" / f"{char_id}_{expression}.png"
            draw_portrait(char_id, expression).save(path)
            print("wrote", path.relative_to(ROOT))
        sil = ASSETS / "silhouettes" / f"{char_id}_sil.png"
        draw_silhouette(char_id).save(sil)
        print("wrote", sil.relative_to(ROOT))

    for loc in ["foyer", "salon", "terrace", "study_annex", "cloakroom", "briefing"]:
        path = ASSETS / "backgrounds" / f"{loc}_bg.png"
        draw_background(loc).save(path)
        print("wrote", path.relative_to(ROOT))

    draw_ui_chrome()
    print("wrote ui chrome")
    print("done")


if __name__ == "__main__":
    main()
