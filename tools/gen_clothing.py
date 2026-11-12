#!/usr/bin/env python3
"""Draws original Roblox classic clothing templates (Shirt / Pants, 585x559)
for the martial arts outfits into assets/clothing/*.png.

Template regions (Roblox classic clothing layout):
  torso:  up (231,8,128x64)  front (231,74,128x128)  right side (165,74,64x128)
          left side (361,74,64x128)  back (427,74,128x128)  down (231,204,128x64)
  right limb: front (217,355,64x128) up (217,289,64x64) down (217,485,64x64)
              sides/back: (19,355) (85,355) (151,355)
  left limb:  front (308,355,64x128) up (308,289,64x64) down (308,485,64x64)
              sides/back: (374,355) (440,355) (506,355)
For a Shirt the limbs are the arms; for Pants the limbs are the legs and the
torso area is the hips/lower torso.
"""
import os

from PIL import Image, ImageDraw

W, H = 585, 559
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "clothing")

TORSO = {"up": (231, 8, 128, 64), "front": (231, 74, 128, 128), "right": (165, 74, 64, 128),
         "left": (361, 74, 64, 128), "back": (427, 74, 128, 128), "down": (231, 204, 128, 64)}
RLIMB = {"front": (217, 355, 64, 128), "up": (217, 289, 64, 64), "down": (217, 485, 64, 64),
         "a": (19, 355, 64, 128), "b": (85, 355, 64, 128), "c": (151, 355, 64, 128)}
LLIMB = {"front": (308, 355, 64, 128), "up": (308, 289, 64, 64), "down": (308, 485, 64, 64),
         "a": (374, 355, 64, 128), "b": (440, 355, 64, 128), "c": (506, 355, 64, 128)}


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def fill(d, region, color, texture=True):
    x, y, w, h = region
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=color)
    if texture:
        # subtle cloth weave so plain colours do not look flat
        for i in range(0, h, 6):
            d.line([x, y + i, x + w - 1, y + i], fill=shade(color, 0.97))


def all_regions(d, color, limbs=True):
    for r in TORSO.values():
        fill(d, r, color)
    if limbs:
        for r in list(RLIMB.values()) + list(LLIMB.values()):
            fill(d, r, color)


def belt_on_torso(d, color, y_frac, height, knot=True, tails=True):
    for name in ("front", "back", "left", "right"):
        x, y, w, h = TORSO[name]
        by = y + int(h * y_frac)
        d.rectangle([x, by, x + w - 1, by + height], fill=color, outline=shade(color, 0.7))
        if name == "front" and knot:
            cx = x + w // 2
            d.rectangle([cx - 10, by - 3, cx + 10, by + height + 3], fill=color, outline=shade(color, 0.6))
            if tails:
                d.polygon([(cx - 8, by + height), (cx - 2, by + height), (cx - 10, by + height + 34), (cx - 17, by + height + 32)], fill=color, outline=shade(color, 0.6))
                d.polygon([(cx + 2, by + height), (cx + 8, by + height), (cx + 17, by + height + 32), (cx + 10, by + height + 34)], fill=color, outline=shade(color, 0.6))


def gi_shirt(base, lapel, belt, sleeves="long", collar=None):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    all_regions(d, base)
    x, y, w, h = TORSO["front"]
    edge = collar or shade(base, 0.82)
    # crossed lapels (left over right) forming the V
    d.polygon([(x + 14, y), (x + 34, y), (x + w // 2 + 8, y + 86), (x + w // 2 - 8, y + 92)], fill=edge)
    d.polygon([(x + w - 34, y), (x + w - 14, y), (x + w // 2 + 2, y + 98), (x + w // 2 - 14, y + 90)], fill=shade(edge, 0.92))
    d.line([(x + w // 2 - 2, y + 92), (x + w // 2 - 2, y + h)], fill=shade(base, 0.8), width=2)
    # collar continues on the back
    bx, by, bw, bh = TORSO["back"]
    d.rectangle([bx + 34, by, bx + bw - 34, by + 12], fill=edge)
    d.line([(bx + bw // 2, by + 20), (bx + bw // 2, by + bh)], fill=shade(base, 0.86), width=2)
    # sleeve cuffs / seams
    for limb in (RLIMB, LLIMB):
        for key in ("front", "a", "b", "c"):
            lx, ly, lw, lh = limb[key]
            if sleeves == "long":
                d.rectangle([lx, ly + lh - 10, lx + lw - 1, ly + lh - 1], fill=shade(base, 0.9))
            d.line([(lx + lw // 2, ly), (lx + lw // 2, ly + lh)], fill=shade(base, 0.93))
    if belt:
        belt_on_torso(d, belt[0], 0.82, 12)
        if len(belt) > 1 and belt[1]:
            # rank bars (dan stripes / BJJ black-belt bar) on the belt ends
            fx, fy, fw, fh = TORSO["front"]
            by = fy + int(fh * 0.82)
            for i in range(belt[2] if len(belt) > 2 else 1):
                d.rectangle([fx + fw // 2 + 26 + i * 8, by + 1, fx + fw // 2 + 31 + i * 8, by + 11], fill=belt[1])
            d.polygon([(fx + fw // 2 + 2, by + 12), (fx + fw // 2 + 8, by + 12), (fx + fw // 2 + 17, by + 44), (fx + fw // 2 + 10, by + 46)], fill=belt[1])
    return img


def gi_pants(base, belt=None):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    all_regions(d, base)
    for limb in (RLIMB, LLIMB):
        lx, ly, lw, lh = limb["front"]
        d.line([(lx + lw // 2, ly), (lx + lw // 2, ly + lh)], fill=shade(base, 0.9), width=2)
        d.rectangle([lx, ly + lh - 8, lx + lw - 1, ly + lh - 1], fill=shade(base, 0.9))
    if belt:
        belt_on_torso(d, belt, 0.0, 14, knot=True, tails=True)
    return img


def shorts(base, band, text_color=None, length=0.45):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for r in TORSO.values():
        fill(d, r, base)
    for limb in (RLIMB, LLIMB):
        for key in ("front", "a", "b", "c", "up"):
            lx, ly, lw, lh = limb[key]
            hh = lh if key == "up" else int(lh * length)
            d.rectangle([lx, ly, lx + lw - 1, ly + hh - 1], fill=base)
            if key != "up":
                d.line([(lx, ly + hh - 1), (lx + lw - 1, ly + hh - 1)], fill=shade(base, 0.7), width=3)
    for name in ("front", "back", "left", "right"):
        x, y, w, h = TORSO[name]
        d.rectangle([x, y, x + w - 1, y + 22], fill=band)
    if text_color:
        x, y, w, h = TORSO["front"]
        # Thai-style lettering block on the front of the shorts
        for i in range(5):
            d.rectangle([x + 22 + i * 18, y + 50, x + 34 + i * 18, y + 66], fill=text_color)
    return img


def mawashi(color):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for name in ("front", "back", "left", "right"):
        x, y, w, h = TORSO[name]
        d.rectangle([x, y, x + w - 1, y + 60], fill=color)
        d.line([x, y + 30, x + w - 1, y + 30], fill=shade(color, 0.8), width=2)
    x, y, w, h = TORSO["front"]
    for i in range(7):
        d.rectangle([x + 20 + i * 14, y + 60, x + 25 + i * 14, y + 118], fill=shade(color, 0.85))
    bx, by, bw, bh = TORSO["back"]
    d.rectangle([bx + bw // 2 - 14, by + 60, bx + bw // 2 + 14, by + bh - 1], fill=color)
    for limb in (RLIMB, LLIMB):
        for key in ("front", "a", "b", "c"):
            lx, ly, lw, lh = limb[key]
            d.polygon([(lx, ly), (lx + lw - 1, ly), (lx + lw - 1, ly + 10), (lx, ly + 22)], fill=color)
    return img


def kungfu_shirt(base, trim):
    img = gi_shirt(base, trim, None, collar=base)
    d = ImageDraw.Draw(img)
    x, y, w, h = TORSO["front"]
    d.rectangle([x + 40, y, x + w - 40, y + 10], fill=trim)
    for i in range(5):
        cy = y + 20 + i * 20
        d.rectangle([x + w // 2 - 12, cy, x + w // 2 + 12, cy + 5], fill=trim)
        d.ellipse([x + w // 2 - 3, cy - 2, x + w // 2 + 3, cy + 7], fill=trim)
    for limb in (RLIMB, LLIMB):
        for key in ("front", "a", "b", "c"):
            lx, ly, lw, lh = limb[key]
            d.rectangle([lx, ly + lh - 14, lx + lw - 1, ly + lh - 1], fill=trim)
    return img


def rashguard(base, stripe):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    all_regions(d, base)
    for name in ("front", "back"):
        x, y, w, h = TORSO[name]
        d.polygon([(x, y + 40), (x + w, y + 10), (x + w, y + 30), (x, y + 60)], fill=stripe)
    for limb in (RLIMB, LLIMB):
        lx, ly, lw, lh = limb["a"]
        d.rectangle([lx + lw // 2 - 4, ly, lx + lw // 2 + 4, ly + lh], fill=stripe)
    return img


def suit_shirt(base, trim):
    img = gi_shirt(base, trim, None, collar=trim)
    d = ImageDraw.Draw(img)
    x, y, w, h = TORSO["front"]
    d.polygon([(x + w // 2 - 6, y + 4), (x + w // 2 + 6, y + 4), (x + w // 2 + 4, y + 80), (x + w // 2, y + 90), (x + w // 2 - 4, y + 80)], fill=trim)
    for i in range(3):
        d.ellipse([x + w // 2 + 12, y + 70 + i * 16, x + w // 2 + 18, y + 76 + i * 16], fill=trim)
    return img


WHITE = (245, 245, 240)
BLACK = (25, 25, 28)
GOLD = (212, 175, 55)
RED = (190, 30, 35)

ITEMS = {
    "karate_gi_white_belt_shirt": lambda: gi_shirt(WHITE, None, [WHITE]),
    "karate_gi_black_belt_shirt": lambda: gi_shirt(WHITE, None, [BLACK]),
    "karate_gi_red_belt_shirt": lambda: gi_shirt(WHITE, None, [RED]),
    "karate_gi_pants": lambda: gi_pants(WHITE),
    "judogi_black_belt_shirt": lambda: gi_shirt(WHITE, None, [BLACK], collar=(225, 225, 218)),
    "bjj_gi_black_belt_shirt": lambda: gi_shirt(WHITE, None, [BLACK, RED]),
    "dobok_black_belt_shirt": lambda: gi_shirt(WHITE, None, [BLACK], collar=BLACK),
    "kungfu_shirt": lambda: kungfu_shirt((180, 30, 30), GOLD),
    "kungfu_pants": lambda: gi_pants(BLACK),
    "boxing_shorts_red": lambda: shorts(RED, (240, 240, 240)),
    "boxing_shorts_gold": lambda: shorts(GOLD, (30, 30, 30)),
    "muaythai_shorts_red": lambda: shorts((220, 40, 60), (240, 240, 240), (240, 220, 120), 0.4),
    "muaythai_shorts_gold": lambda: shorts(GOLD, (240, 240, 240), (200, 30, 40), 0.4),
    "mma_rashguard": lambda: rashguard(BLACK, (230, 30, 30)),
    "mma_shorts": lambda: shorts((230, 30, 30), BLACK, None, 0.55),
    "mawashi_navy": lambda: mawashi((40, 50, 80)),
    "mawashi_gold": lambda: mawashi(GOLD),
    "owner_suit_shirt": lambda: suit_shirt((30, 28, 26), GOLD),
    "owner_suit_pants": lambda: gi_pants((30, 28, 26)),
}


def sash_shirt(base, trim, sash):
    """Kung fu uniform: frog buttons + a sash knotted at the side."""
    img = kungfu_shirt(base, trim)
    d = ImageDraw.Draw(img)
    for name in ("front", "back", "left", "right"):
        x, y, w, h = TORSO[name]
        by = y + int(h * 0.8)
        d.rectangle([x, by, x + w - 1, by + 16], fill=sash, outline=shade(sash, 0.7))
    x, y, w, h = TORSO["left"]
    by = y + int(h * 0.8)
    d.polygon([(x + 18, by + 16), (x + 30, by + 16), (x + 34, by + 60), (x + 14, by + 60)], fill=sash, outline=shade(sash, 0.7))
    return img


def prajiad_shirt(color):
    """Muay Thai: bare chest, only the armbands (transparent elsewhere)."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for limb in (RLIMB, LLIMB):
        for key in ("front", "a", "b", "c"):
            lx, ly, lw, lh = limb[key]
            d.rectangle([lx, ly + 18, lx + lw - 1, ly + 34], fill=color, outline=shade(color, 0.6))
            # twisted cord look
            for i in range(0, lw, 8):
                d.line([(lx + i, ly + 18), (lx + i + 6, ly + 34)], fill=shade(color, 0.75), width=2)
    return img


def sumo_rank(rank, total):
    if rank == total:  # yokozuna: purple silk mawashi + white rope with paper zigzags
        img = mawashi((90, 40, 120))
        d = ImageDraw.Draw(img)
        for name in ("front", "back", "left", "right"):
            x, y, w, h = TORSO[name]
            d.rectangle([x, y + 4, x + w - 1, y + 22], fill=(245, 245, 240), outline=(200, 200, 190))
            for i in range(0, w, 12):
                d.line([(x + i, y + 4), (x + i + 10, y + 22)], fill=(205, 205, 195), width=2)
        x, y, w, h = TORSO["front"]
        for cx in (x + 30, x + 64, x + 98):
            d.polygon([(cx - 6, y + 22), (cx + 6, y + 22), (cx - 2, y + 34), (cx + 8, y + 34), (cx - 4, y + 48), (cx - 8, y + 36)], fill=(250, 250, 250))
        return img
    colors = [(30, 30, 35), (35, 40, 60), (40, 45, 70), (45, 50, 80), (110, 50, 150), (35, 85, 185), (212, 175, 55)]
    return mawashi(colors[min(rank, len(colors)) - 1])


def champion_belt(img):
    """Adds a gold championship belt around the waist of a pants template."""
    d = ImageDraw.Draw(img)
    for name in ("front", "back", "left", "right"):
        x, y, w, h = TORSO[name]
        d.rectangle([x, y + 2, x + w - 1, y + 26], fill=(150, 30, 30), outline=(90, 20, 20))
    x, y, w, h = TORSO["front"]
    d.ellipse([x + w // 2 - 26, y - 2, x + w // 2 + 26, y + 32], fill=GOLD, outline=(150, 120, 30), width=3)
    d.ellipse([x + w // 2 - 12, y + 6, x + w // 2 + 12, y + 24], fill=(240, 220, 120))
    return img


def rank_items():
    """Rank-based outfits: one template per rank so the belt shows progress."""
    import json
    ranks = json.load(open(os.path.join(os.path.dirname(OUT), "..", "build", "ranks.json")))
    items = {}

    def belt_spec(r):
        stripe = tuple(r["stripe"]) if r["stripe"] else None
        return (tuple(r["color"]), stripe, 1)

    for i, r in enumerate(ranks["karate"], 1):
        spec = belt_spec(r)
        if spec[1]:
            spec = (spec[0], spec[1], i - 6)  # 2nd dan = 2 bars, 3rd dan = 3 bars
        items[f"karate_r{i}"] = (lambda spec=spec: gi_shirt(WHITE, None, list(spec)))
        items[f"karate_red_r{i}"] = (lambda spec=spec: gi_shirt(WHITE, None, list(spec), collar=RED))
    for i, r in enumerate(ranks["judo"], 1):
        spec = belt_spec(r)
        if r["name"].startswith("Red-White"):
            spec = ((190, 30, 35), (245, 245, 240), 6)
        items[f"judo_r{i}"] = (lambda spec=spec: gi_shirt(WHITE, None, list(spec), collar=(225, 225, 218)))
    for i, r in enumerate(ranks["taekwondo"], 1):
        spec = belt_spec(r)
        collar = BLACK if r["name"].startswith("Black") else (230, 230, 225)
        items[f"tkd_r{i}"] = (lambda spec=spec, collar=collar: gi_shirt(WHITE, None, list(spec), collar=collar))
    for i, r in enumerate(ranks["bjj"], 1):
        spec = belt_spec(r)
        items[f"bjj_r{i}"] = (lambda spec=spec: gi_shirt(WHITE, None, list(spec)))
        items[f"bjj_black_r{i}"] = (lambda spec=spec: gi_shirt(BLACK, None, list(spec), collar=(45, 45, 50)))
    for i, r in enumerate(ranks["kungfu"], 1):
        items[f"kungfu_r{i}"] = (lambda c=tuple(r["color"]): sash_shirt(BLACK, (240, 240, 240), c))
    for i, r in enumerate(ranks["muaythai"], 1):
        items[f"muaythai_r{i}"] = (lambda c=tuple(r["color"]): prajiad_shirt(c))
    total = len(ranks["sumo"])
    for i in range(1, total + 1):
        items[f"sumo_r{i}"] = (lambda i=i: sumo_rank(i, total))
    items["boxing_shorts_red_champ"] = lambda: champion_belt(shorts(RED, (240, 240, 240)))
    items["kickboxing_shorts_champ"] = lambda: champion_belt(shorts(BLACK, (230, 120, 20)))
    items["kickboxing_shorts"] = lambda: shorts(BLACK, (230, 120, 20))
    items["mma_shorts_champ"] = lambda: champion_belt(shorts((230, 30, 30), BLACK, None, 0.55))
    return items


def main():
    ITEMS.update(rank_items())
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ITEMS.items():
        fn().save(os.path.join(OUT, name + ".png"))
    # preview sheet of all templates
    cols = 5
    rows = (len(ITEMS) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * 300, rows * 300), (60, 60, 70, 255))
    for i, name in enumerate(ITEMS):
        im = Image.open(os.path.join(OUT, name + ".png")).resize((292, 279))
        sheet.alpha_composite(im, ((i % cols) * 300 + 4, (i // cols) * 300 + 4))
    sheet.save(os.path.join(os.path.dirname(OUT), "..", "build", "clothing_sheet.png"))
    print("wrote", len(ITEMS), "templates to", os.path.relpath(OUT))


if __name__ == "__main__":
    main()
