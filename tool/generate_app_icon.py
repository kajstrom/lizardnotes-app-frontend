"""Generate the LizardNotes lizard app icon and write the Android launcher assets.

Run from the repo root:

    python3 tool/generate_app_icon.py android/app/src/main/res

Requires Pillow (pip install Pillow). Regenerate whenever the artwork or the
design tokens change; the PNGs are committed so a normal build needs no Python.

Draws a top-down lizard silhouette from bezier centrelines with a variable
width profile, supersampled 4x then downsampled for antialiasing.

Colours come from the DESIGNS.md token system:
  --ln-surface  #222222  icon background
  --ln-accent   #7c6fcd  lizard body
  --ln-accent2  #a89de0  highlight
"""
import math
import os
import sys

from PIL import Image, ImageDraw

SS = 4  # supersample factor
ACCENT = (124, 111, 205, 255)   # --ln-accent
ACCENT2 = (168, 157, 224, 255)  # --ln-accent2
SURFACE = (34, 34, 34, 255)     # --ln-surface


def bezier(p0, p1, p2, p3, n):
    """Sample a cubic bezier into n points."""
    out = []
    for i in range(n):
        t = i / (n - 1)
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        out.append((x, y))
    return out


def chain(segments, per=60):
    """Concatenate cubic bezier segments into one polyline."""
    pts = []
    for seg in segments:
        s = bezier(*seg, per)
        pts.extend(s if not pts else s[1:])
    return pts


def normals(pts):
    """Unit normals along a polyline."""
    out = []
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1.0
        out.append((-dy / L, dx / L))
    return out


def ribbon(pts, widths):
    """Build a closed outline around a centreline with per-point half-widths."""
    ns = normals(pts)
    left = [(p[0] + n[0] * w, p[1] + n[1] * w) for p, n, w in zip(pts, ns, widths)]
    right = [(p[0] - n[0] * w, p[1] - n[1] * w) for p, n, w in zip(pts, ns, widths)]
    return left + right[::-1]


def width_profile(n, stops):
    """Interpolate half-widths across n samples from (t, width) stops."""
    out = []
    for i in range(n):
        t = i / (n - 1)
        for j in range(len(stops) - 1):
            t0, w0 = stops[j]
            t1, w1 = stops[j + 1]
            if t0 <= t <= t1:
                f = (t - t0) / (t1 - t0) if t1 > t0 else 0
                f = f * f * (3 - 2 * f)  # smoothstep
                out.append(w0 + (w1 - w0) * f)
                break
        else:
            out.append(stops[-1][1])
    return out


def draw_lizard(size, colour=ACCENT, highlight=ACCENT2):
    """Draw the lizard on a transparent square canvas of the given size."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = S / 1000.0  # design units -> pixels

    def P(x, y):
        return (x * u, y * u)

    # ── Limbs drawn first so they tuck under the body ───────────────────────
    # (attach, elbow, wrist, foot, toe-splay direction in degrees)
    limbs = [
        # front left
        ((470, 355), (375, 380), (300, 355), (248, 308), 205),
        # front right
        ((530, 355), (625, 380), (700, 355), (752, 308), 335),
        # hind left
        ((510, 545), (405, 580), (325, 585), (272, 638), 162),
        # hind right — raised into a running pose so the tail curl clears it
        ((566, 536), (648, 518), (710, 488), (762, 462), 342),
    ]
    for attach, elbow, wrist, foot, toe_dir in limbs:
        leg = chain([
            (P(*attach), P(*elbow), P(*elbow), P(*wrist)),
            (P(*wrist), P(*wrist), P(*foot), P(*foot)),
        ], per=44)
        lw = width_profile(len(leg), [(0.0, 30), (0.45, 21), (0.8, 15), (1.0, 12)])
        d.polygon(ribbon(leg, [w * u for w in lw]), fill=colour)

        # Toes: three short tapered spurs fanning from the foot.
        for k in (-32, 0, 32):
            a = math.radians(toe_dir + k)
            tip = (foot[0] + math.cos(a) * 62, foot[1] + math.sin(a) * 62)
            toe = chain([(P(*foot), P(*foot), P(*tip), P(*tip))], per=20)
            tw = width_profile(len(toe), [(0.0, 13), (1.0, 5)])
            d.polygon(ribbon(toe, [w * u for w in tw]), fill=colour)

    # ── Body + tail centreline: head at top, tail sweeps right and curls ────
    spine = chain([
        (P(500, 180), P(500, 240), P(500, 275), P(500, 330)),   # head → neck
        (P(500, 330), P(500, 430), P(518, 505), P(538, 585)),   # torso
        (P(538, 585), P(558, 668), P(600, 728), P(668, 754)),   # hips → tail base
        (P(668, 754), P(760, 790), P(846, 738), P(844, 656)),   # tail sweeps right
        (P(844, 656), P(842, 592), P(774, 560), P(722, 596)),   # tail curls up
        (P(722, 596), P(690, 618), P(688, 658), P(714, 676)),   # tail tip hook
    ], per=70)

    widths = width_profile(len(spine), [
        (0.00, 62), (0.09, 50),                # neck
        (0.22, 74), (0.34, 80), (0.46, 72),    # torso
        (0.55, 58),                            # hips
        (0.63, 40), (0.75, 27), (0.87, 16), (1.00, 5),  # tail taper
    ])
    d.polygon(ribbon(spine, [w * u for w in widths]), fill=colour)

    # ── Head: an ellipse gives a rounded snout the ribbon's flat cap can't ──
    hx, hy = P(500, 196)
    rx, ry = 80 * u, 92 * u
    d.ellipse([hx - rx, hy - ry, hx + rx, hy + ry], fill=colour)

    # ── Dorsal highlight: a slim stripe down the back ───────────────────────
    stripe = spine[: int(len(spine) * 0.52)]
    sw = width_profile(len(stripe), [(0.0, 26), (0.18, 15), (0.5, 22), (1.0, 8)])
    d.polygon(ribbon(stripe, [w * u for w in sw]), fill=highlight)

    # ── Eyes ────────────────────────────────────────────────────────────────
    for ex in (455, 545):
        r = 15 * u
        cx, cy = P(ex, 196)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SURFACE)

    return img.resize((size, size), Image.LANCZOS)


def rounded_square(size, radius_frac, colour):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        [0, 0, S - 1, S - 1], radius=int(S * radius_frac), fill=colour
    )
    return img.resize((size, size), Image.LANCZOS)


def compose(size, art_frac, with_bg):
    """Place the lizard art centred at art_frac of the canvas."""
    base = (rounded_square(size, 0.22, SURFACE) if with_bg
            else Image.new("RGBA", (size, size), (0, 0, 0, 0)))
    a = max(1, int(size * art_frac))
    art = draw_lizard(a)
    off = (size - a) // 2
    base.alpha_composite(art, (off, off))
    return base


# ---------------------------------------------------------------------------
# Android asset generation
# ---------------------------------------------------------------------------

RES = sys.argv[1]

# density -> (legacy px, adaptive px). Adaptive canvas is 108dp vs 48dp legacy.
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

WHITE = (255, 255, 255, 255)


def art(size, colour, highlight, eyes):
    """Render the lizard at high resolution, cropped to its own alpha bbox.

    Cropping first means the caller controls exactly how much of the target
    canvas the visible artwork occupies, independent of the design's padding.
    """
    img = draw_lizard(size, colour=colour, highlight=highlight)
    if not eyes:
        # Themed icons are a flat silhouette: punch the eyes out instead of
        # filling them, so the system tint doesn't leave dark blobs.
        base = draw_lizard(size, colour=colour, highlight=highlight)
        px = base.load()
        for y in range(size):
            for x in range(size):
                r, g, b, a = px[x, y]
                if a > 0 and (r, g, b) == SURFACE[:3]:
                    px[x, y] = (0, 0, 0, 0)
        img = base
    return img.crop(img.getbbox())


def _max_radius(img):
    """Largest distance from centre to any opaque pixel."""
    px = img.load()
    cx, cy = img.width / 2, img.height / 2
    best = 0.0
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3] > 8:
                r = math.hypot(x - cx, y - cy)
                if r > best:
                    best = r
    return best


def place(canvas_px, content_frac, colour, highlight, background, eyes=True,
          radius_frac=None):
    """Centre the cropped artwork on a square canvas.

    content_frac sizes by bounding box. radius_frac, when given, instead sizes
    so no opaque pixel exceeds that fraction of the canvas from the centre —
    which is the constraint that actually matters for adaptive icons, since
    launcher masks are round and a bbox fit lets the corners clip.
    """
    render_at = max(canvas_px * 4, 512)
    a = art(render_at, colour, highlight, eyes)

    if radius_frac is not None:
        scale = (canvas_px * radius_frac) / _max_radius(a)
    else:
        scale = (canvas_px * content_frac) / max(a.width, a.height)
    a = a.resize(
        (max(1, round(a.width * scale)), max(1, round(a.height * scale))),
        Image.LANCZOS,
    )

    base = (rounded_square(canvas_px, 0.22, background) if background
            else Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0)))
    base.alpha_composite(a, ((canvas_px - a.width) // 2,
                             (canvas_px - a.height) // 2))
    return base


def write(path, img):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print(f"  {os.path.relpath(path, RES):<52} {img.width}x{img.height}")


for density, (legacy, adaptive) in DENSITIES.items():
    d = os.path.join(RES, f"mipmap-{density}")

    # Legacy icon: full-bleed rounded square, artwork at 72% of the canvas.
    write(os.path.join(d, "ic_launcher.png"),
          place(legacy, 0.72, ACCENT, ACCENT2, SURFACE))

    # Adaptive foreground: 108dp canvas, artwork kept inside the 66dp keyline
    # so no launcher mask (circle, squircle, teardrop) clips it.
    write(os.path.join(d, "ic_launcher_foreground.png"),
          place(adaptive, None, ACCENT, ACCENT2, None, radius_frac=33 / 108))

    # Themed icon (API 33+): flat white silhouette, system applies the tint.
    write(os.path.join(d, "ic_launcher_monochrome.png"),
          place(adaptive, None, WHITE, WHITE, None, eyes=False,
                radius_frac=33 / 108))

anydpi = os.path.join(RES, "mipmap-anydpi-v26")
os.makedirs(anydpi, exist_ok=True)
with open(os.path.join(anydpi, "ic_launcher.xml"), "w") as f:
    f.write("""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
""")
print("  mipmap-anydpi-v26/ic_launcher.xml")

with open(os.path.join(RES, "values", "ic_launcher_background.xml"), "w") as f:
    f.write("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- ln-surface token from DESIGNS.md (XML comments cannot contain "-" twice) -->
    <color name="ic_launcher_background">#222222</color>
</resources>
""")
print("  values/ic_launcher_background.xml")
