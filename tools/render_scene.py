#!/usr/bin/env python3
"""Renders a whole plot exported by tests/render_plot.lua (bird's-eye view).

    CITY=tokyo lua5.4 tests/render_plot.lua > build/plot.txt
    python3 tools/render_scene.py build/plot.txt docs/images/academy.png
"""
import math
import sys

from PIL import Image, ImageDraw

CORNERS = [(sx, sy, sz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
LIGHT = (-0.35, 0.85, -0.4)


def main():
    src, out = sys.argv[1], sys.argv[2]
    parts = []
    for line in open(src):
        v = line.split()
        if v and v[0] == "P":
            parts.append(list(map(float, v[1:19])))
    # camera: look at the plot centre from the entrance side, high above
    cx = sum(p[0] for p in parts) / len(parts)
    cz = sum(p[2] for p in parts) / len(parts)
    target = (cx, 0.0, cz)
    # entrance of plot 5 faces -z (towards the boulevard)
    eye = (cx + 120.0, 210.0, cz - 230.0)
    fwd = [target[i] - eye[i] for i in range(3)]
    fl = math.sqrt(sum(f * f for f in fwd))
    fwd = [f / fl for f in fwd]
    right = [-fwd[2], 0.0, fwd[0]]
    rl = math.sqrt(sum(r * r for r in right))
    right = [r / rl for r in right]
    up = [right[1] * fwd[2] - right[2] * fwd[1], right[2] * fwd[0] - right[0] * fwd[2], right[0] * fwd[1] - right[1] * fwd[0]]
    W, H = 1800, 1200

    def project(p):
        d = [p[i] - eye[i] for i in range(3)]
        z = sum(d[i] * fwd[i] for i in range(3))
        x = sum(d[i] * right[i] for i in range(3))
        y = sum(d[i] * up[i] for i in range(3))
        f = 1500 / max(z, 1)
        return W / 2 + x * f, H / 2 - y * f, z

    polys = []
    for n in parts:
        px, py, pz = n[0:3]
        r = n[3:12]
        sx, sy, sz = n[12:15]
        color = tuple(int(c * 255) for c in n[15:18])
        corners = []
        for ax, ay, az in CORNERS:
            lx, ly, lz = ax * sx / 2, ay * sy / 2, az * sz / 2
            corners.append((r[0] * lx + r[1] * ly + r[2] * lz + px, r[3] * lx + r[4] * ly + r[5] * lz + py, r[6] * lx + r[7] * ly + r[8] * lz + pz))
        for face in FACES:
            pts = [corners[i] for i in face]
            a = [pts[1][i] - pts[0][i] for i in range(3)]
            b = [pts[3][i] - pts[0][i] for i in range(3)]
            nx, ny, nz = a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]
            nl = math.sqrt(nx * nx + ny * ny + nz * nz) or 1
            shade = max(0.4, min(1.0, 0.5 + 0.55 * abs(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / nl))
            proj = [project(p) for p in pts]
            if min(p[2] for p in proj) <= 1:
                continue
            depth = max(p[2] for p in proj)
            polys.append((depth, [(p[0], p[1]) for p in proj], tuple(int(c * shade) for c in color)))
    polys.sort(key=lambda t: -t[0])
    img = Image.new("RGB", (W, H), (150, 185, 215))
    draw = ImageDraw.Draw(img)
    for _, pts, col in polys:
        draw.polygon(pts, fill=col)
    img.save(out)
    print("wrote", out, len(parts), "parts")


if __name__ == "__main__":
    main()
