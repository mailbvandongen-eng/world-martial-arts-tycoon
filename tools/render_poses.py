#!/usr/bin/env python3
"""Draws the posed rigs exported by tests/render_poses.lua as a contact sheet.

    lua5.4 tests/render_poses.lua disciplines > build/poses.txt
    python3 tools/render_poses.py build/poses.txt build/poses.png 4

Flat-shaded boxes (balls drawn as boxes too), painter's algorithm, camera in
front of the figure, slightly from above. Good enough to check that every
discipline's clothing and every keyframe look right without Roblox Studio.
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFont


def load(path):
    figures = []
    for line in open(path):
        line = line.rstrip("\n")
        if line.startswith("F "):
            figures.append((line[2:], []))
        elif line.startswith("P "):
            v = line.split()
            nums = list(map(float, v[1:19]))
            figures[-1][1].append((nums, v[19]))
    return figures


CORNERS = [(sx, sy, sz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
LIGHT = (-0.4, 0.8, -0.45)


def project(p, yaw=math.radians(15), pitch=math.radians(12), dist=13.0, center_y=2.8):
    x, y, z = p
    # rotate the world around Y, then tilt
    cx, sx = math.cos(yaw), math.sin(yaw)
    x, z = cx * x + sx * z, -sx * x + cx * z
    y -= center_y
    cp, sp = math.cos(pitch), math.sin(pitch)
    y, z = cp * y - sp * z, sp * y + cp * z
    # camera looks along +z from z = -dist
    depth = z + dist
    f = 420 / depth
    # camera looks along +z, so world +x appears on the left of the image
    return -x * f, -y * f, depth


def draw_figure(draw, ox, oy, parts, scale=1.0):
    polys = []
    for nums, shape in parts:
        px, py, pz = nums[0:3]
        r = nums[3:12]
        sx, sy, sz = nums[12:15]
        color = tuple(int(c * 255) for c in nums[15:18])
        corners = []
        for cx, cy, cz in CORNERS:
            lx, ly, lz = cx * sx / 2, cy * sy / 2, cz * sz / 2
            wx = r[0] * lx + r[1] * ly + r[2] * lz + px
            wy = r[3] * lx + r[4] * ly + r[5] * lz + py
            wz = r[6] * lx + r[7] * ly + r[8] * lz + pz
            corners.append((wx, wy, wz))
        for face in FACES:
            pts = [corners[i] for i in face]
            # normal
            ax, ay, az = (pts[1][0] - pts[0][0], pts[1][1] - pts[0][1], pts[1][2] - pts[0][2])
            bx, by, bz = (pts[3][0] - pts[0][0], pts[3][1] - pts[0][1], pts[3][2] - pts[0][2])
            nx, ny, nz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
            nl = math.sqrt(nx * nx + ny * ny + nz * nz) or 1
            shade = max(0.35, min(1.0, 0.55 + 0.5 * abs(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / nl))
            proj = [project(p) for p in pts]
            depth = sum(p[2] for p in proj) / 4
            col = tuple(int(c * shade) for c in color)
            polys.append((depth, [(ox + p[0] * scale, oy + p[1] * scale) for p in proj], col))
    polys.sort(key=lambda t: -t[0])
    for _, pts, col in polys:
        draw.polygon(pts, fill=col, outline=(20, 20, 20))


def main():
    src, out = sys.argv[1], sys.argv[2]
    cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    figures = load(src)
    cw, ch = 230, 300
    rows = math.ceil(len(figures) / cols)
    img = Image.new("RGB", (cols * cw, rows * ch), (36, 36, 42))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    for i, (title, parts) in enumerate(figures):
        cx = (i % cols) * cw + cw // 2
        cy = (i // cols) * ch + ch // 2 + 10
        # floor line
        fy = cy + project((0, 0, 0))[1]
        draw.line([(cx - 90, fy), (cx + 90, fy)], fill=(90, 90, 100), width=2)
        draw_figure(draw, cx, cy, parts)
        draw.text(((i % cols) * cw + 8, (i // cols) * ch + 6), title, fill=(230, 200, 90), font=font)
    img.save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
