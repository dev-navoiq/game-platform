"""Generate Gathr placeholder branding assets.

Produces three PNGs in apps/flutter_app/assets/branding/:
  - icon_source.png            1024x1024  full app icon (felt BG + glyph)
  - icon_foreground.png        1024x1024  glyph only on transparent (Android adaptive)
  - splash_logo.png            1024x512   wordmark + glyph for splash screen

Design language: "Refined Crystal"
  felt green  #122e1d  (background)
  gold accent #C47B2B  (primary mark)
  ivory tint  #F5E6CA  (highlight)
"""

from __future__ import annotations

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


FELT = (18, 46, 29, 255)
FELT_DARK = (9, 28, 17, 255)
GOLD = (196, 123, 43, 255)
GOLD_LIGHT = (224, 165, 95, 255)
IVORY = (245, 230, 202, 255)
SHADOW = (0, 0, 0, 90)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "apps/flutter_app/assets/branding"
OUT.mkdir(parents=True, exist_ok=True)


def radial_felt(size: int) -> Image.Image:
    """Felt-green background with subtle vignette."""
    img = Image.new("RGBA", (size, size), FELT)
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    cx, cy = size / 2, size / 2
    max_r = size * 0.72
    # build a soft radial darken toward edges
    steps = 60
    for i in range(steps):
        t = i / steps
        r = max_r + (size * 0.45 - max_r) * t
        alpha = int(2 + 70 * (t ** 1.6))
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            outline=None,
            fill=None,
            width=0,
        )
        # paint a translucent ring by drawing a slightly larger ellipse subtract
        draw.ellipse(
            [cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6],
            outline=(0, 0, 0, alpha),
            width=8,
        )
    img = Image.alpha_composite(img, overlay)
    return img


def gathering_glyph(size: int, scale: float = 0.78) -> Image.Image:
    """A 'gathering' mark: three overlapping rounded chips arranged like a
    huddle, with a centered crescent suggesting a G."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size / 2, size / 2
    R = size * 0.36 * scale  # outer ring radius for the G
    ring_w = size * 0.09 * scale  # G stroke width

    # --- Outer gold ring (the G body) ---
    # draw filled gold disc, then knock out inner felt disc
    draw.ellipse(
        [cx - R, cy - R, cx + R, cy + R],
        fill=GOLD,
    )
    inner = R - ring_w
    draw.ellipse(
        [cx - inner, cy - inner, cx + inner, cy + inner],
        fill=(0, 0, 0, 0),
    )

    # Cut the G opening on the right side: erase a wedge
    wedge = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    wedge_draw = ImageDraw.Draw(wedge)
    # opening pointing right, from ~ -30deg to +30deg
    wedge_draw.pieslice(
        [cx - R - 4, cy - R - 4, cx + R + 4, cy + R + 4],
        start=-28,
        end=28,
        fill=(0, 0, 0, 255),
    )
    # use wedge as a mask to erase that arc from the gold ring
    r, g, b, a = img.split()
    wedge_alpha = wedge.split()[-1]
    # subtract wedge alpha from glyph alpha
    a = Image.eval(Image.merge("L", (a,)).point(lambda v: v), lambda v: v)
    new_alpha = Image.new("L", (size, size))
    for x in range(size):
        pass  # placeholder; do this in numpy-like way below

    # cheaper: composite a felt-colored wedge over the ring to "cut" it,
    # then draw the inner crossbar in gold.
    cut = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cut_draw = ImageDraw.Draw(cut)
    cut_draw.pieslice(
        [cx - R - 4, cy - R - 4, cx + R + 4, cy + R + 4],
        start=-26,
        end=26,
        fill=(0, 0, 0, 0),
    )
    # Instead: redraw the ring as a thick arc that doesn't include the wedge.
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    bbox = [cx - R, cy - R, cx + R, cy + R]
    # draw arc from 26 -> 360-26 (i.e. skipping the right opening)
    draw.arc(bbox, start=26, end=360 - 26, fill=GOLD, width=int(ring_w))

    # G crossbar: horizontal gold bar from center to opening
    bar_h = ring_w * 0.85
    bar_x0 = cx - ring_w * 0.2
    bar_x1 = cx + R - ring_w * 0.35
    bar_y0 = cy - bar_h / 2
    bar_y1 = cy + bar_h / 2
    draw.rounded_rectangle(
        [bar_x0, bar_y0, bar_x1, bar_y1],
        radius=ring_w * 0.4,
        fill=GOLD,
    )

    # Three small "chip" dots around the G suggesting players gathered
    chip_r = size * 0.045 * scale
    chip_orbit = R + ring_w * 0.9
    for angle_deg in (210, 270, 330):
        a = math.radians(angle_deg)
        px = cx + chip_orbit * math.cos(a)
        py = cy + chip_orbit * math.sin(a)
        draw.ellipse(
            [px - chip_r, py - chip_r, px + chip_r, py + chip_r],
            fill=GOLD_LIGHT,
        )

    # Soft highlight on top-left of ring
    hl = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hl_draw = ImageDraw.Draw(hl)
    hl_draw.arc(
        [cx - R + 4, cy - R + 4, cx + R - 4, cy + R - 4],
        start=200,
        end=300,
        fill=(255, 240, 210, 110),
        width=int(ring_w * 0.35),
    )
    hl = hl.filter(ImageFilter.GaussianBlur(2.5))
    img = Image.alpha_composite(img, hl)

    return img


def render_icon(size: int = 1024) -> Image.Image:
    bg = radial_felt(size)
    glyph = gathering_glyph(size, scale=1.0)
    return Image.alpha_composite(bg, glyph)


def render_foreground(size: int = 1024) -> Image.Image:
    """Android adaptive icon foreground: glyph only on transparent, with
    safe-zone padding (foreground should fit within ~66% of the canvas)."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glyph = gathering_glyph(size, scale=0.78)
    return Image.alpha_composite(canvas, glyph)


def render_splash(width: int = 1024, height: int = 512) -> Image.Image:
    """Wide splash logo: small glyph + 'Gathr' wordmark on transparent."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    # glyph on the left
    g_size = int(height * 0.85)
    glyph = gathering_glyph(g_size, scale=1.0)
    gx = int(width * 0.18) - g_size // 2
    gy = (height - g_size) // 2
    img.alpha_composite(glyph, (gx, gy))

    # wordmark on the right
    draw = ImageDraw.Draw(img)
    text = "Gathr"
    font = None
    candidate_fonts = [
        "/System/Library/Fonts/Supplemental/Futura.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Avenir Next.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for fp in candidate_fonts:
        if Path(fp).exists():
            try:
                font = ImageFont.truetype(fp, int(height * 0.42))
                break
            except OSError:
                continue
    if font is None:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = int(width * 0.40)
    ty = (height - th) // 2 - bbox[1]
    draw.text((tx, ty), text, fill=IVORY, font=font)

    return img


def main() -> None:
    print(f"Writing branding assets to {OUT}")

    icon = render_icon(1024)
    icon.save(OUT / "icon_source.png", "PNG", optimize=True)
    print(f"  ✓ icon_source.png         {icon.size}")

    fg = render_foreground(1024)
    fg.save(OUT / "icon_foreground.png", "PNG", optimize=True)
    print(f"  ✓ icon_foreground.png     {fg.size}")

    splash = render_splash(1024, 512)
    splash.save(OUT / "splash_logo.png", "PNG", optimize=True)
    print(f"  ✓ splash_logo.png         {splash.size}")

    # also save a preview composite for quick eyeballing
    preview = Image.new("RGBA", (1100, 600), FELT_DARK)
    preview.alpha_composite(icon.resize((480, 480), Image.LANCZOS), (40, 60))
    preview.alpha_composite(splash, (540, 110))
    preview.save(OUT / "preview.png", "PNG", optimize=True)
    print(f"  ✓ preview.png             {preview.size}  (for visual review)")


if __name__ == "__main__":
    main()
