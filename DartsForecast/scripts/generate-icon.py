#!/usr/bin/env python3
"""Generate macOS AppIcon set (dartboard + dart + AI nodes, no 99% text)."""
from __future__ import annotations
import math, struct, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def png(w, h, rgba_fn):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            raw.extend(rgba_fn(x, y, w, h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def clamp(v):
    return max(0, min(255, int(v)))


def icon_fn(x, y, w, h):
    nx = (x + 0.5) / w * 2 - 1
    ny = (y + 0.5) / h * 2 - 1
    ax, ay = abs(nx), abs(ny)
    squircle = (ax**4 + ay**4) ** 0.25
    if squircle > 0.98:
        return (0, 0, 0, 0)
    t = (ny + 1) / 2
    col = (clamp(12 + 20 * t), clamp(40 + 50 * (1 - t)), clamp(48 + 30 * t), 255)
    cx, cy = -0.08, 0.05
    dx, dy = nx - cx, ny - cy
    d = math.hypot(dx, dy)
    if d < 0.62:
        ring = int(d / 0.08)
        col = (clamp(230 - ring * 8), clamp(80 + ring * 5), 70, 255) if ring % 2 == 0 else (245, clamp(235 - ring * 5), 220, 255)
        if abs((d % 0.08) - 0.04) < 0.006:
            col = (40, 40, 40, 255)
        ang = math.atan2(dy, dx)
        spoke = abs((ang / (math.pi / 10)) % 1)
        if (spoke < 0.04 or spoke > 0.96) and d > 0.1:
            col = (35, 35, 35, 255)
        if d < 0.07:
            col = (200, 40, 40, 255)
        if d < 0.03:
            col = (30, 30, 30, 255)
    for i in range(28):
        px, py = 0.18 + i * 0.018, -0.45 + i * 0.012
        if math.hypot(nx - px, ny - py) < 0.025:
            col = (220, 230, 235, 255)
    for i in range(10):
        px, py = 0.55 + i * 0.01, -0.22 + (i - 5) * 0.02
        if abs(nx - px) < 0.05 and abs(ny - py) < 0.08 - abs(i - 5) * 0.005:
            col = (0, 170, 160, 255)
    nodes = [(-0.62, 0.55), (-0.48, 0.42), (-0.55, 0.68), (-0.38, 0.58)]
    for i, (axn, ayn) in enumerate(nodes):
        for j, (bx, by) in enumerate(nodes):
            if j <= i:
                continue
            for k in range(12):
                tt = k / 11
                lx, ly = axn + (bx - axn) * tt, ayn + (by - ayn) * tt
                if math.hypot(nx - lx, ny - ly) < 0.012:
                    col = (80, 220, 200, 255)
        if math.hypot(nx - axn, ny - ayn) < 0.035:
            col = (120, 255, 230, 255)
    if squircle > 0.86:
        a = clamp(255 * (0.98 - squircle) / 0.12)
        return (col[0], col[1], col[2], a)
    return col


def main():
    out = ROOT / "Assets"
    out.mkdir(parents=True, exist_ok=True)
    master = png(1024, 1024, icon_fn)
    (out / "AppIcon-1024.png").write_bytes(master)
    (ROOT / "Sources/DartsForecast/Resources/AppIcon.png").write_bytes(master)
    iconset = out / "AppIcon.iconset"
    iconset.mkdir(exist_ok=True)
    for s in (16, 32, 64, 128, 256, 512, 1024):
        (iconset / f"icon_{s}x{s}.png").write_bytes(png(s, s, icon_fn))
        if s <= 512:
            (iconset / f"icon_{s}x{s}@2x.png").write_bytes(png(s * 2, s * 2, icon_fn))
    print("icons ok")


if __name__ == "__main__":
    main()
