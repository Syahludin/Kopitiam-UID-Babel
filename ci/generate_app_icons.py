#!/usr/bin/env python3
"""Generate every KOPITIAM branding asset from a single source image.

Source priority:
  1. kopitiam_mobile/assets/branding/kopitiam-logo-master-2048.png  (official artwork)
  2. branding/kopitiam_logo_master.png                              (alternate drop-in)
  3. branding/kopitiam_logo.svg                                     (vector fallback)

Run locally:  python3 ci/generate_app_icons.py
CI runs the same command, then commits whatever changed.
"""
from __future__ import annotations

import io
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "kopitiam_mobile"
ANDROID_RES = APP / "android/app/src/main/res"
IOS_ICONS = APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
WEB = APP / "web"
APP_ICONS = APP / "assets/icons"

# Checked in order; the first existing entry wins.
RASTER_SOURCES = [
    APP / "assets/branding/kopitiam-logo-master-2048.png",
    ROOT / "branding/kopitiam_logo_master.png",
]
VECTOR_SOURCE = ROOT / "branding/kopitiam_logo.svg"

BACKGROUND = (7, 45, 67, 255)   # #072D43
BACKGROUND_HEX = "#072D43"
EMBLEM_SCALE = 0.86             # emblem share of the icon, keeps the gold ring clear
FOREGROUND_SCALE = 0.68         # Android adaptive icons crop aggressively

ANDROID_DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# (points, scale, idiom) mirroring the standard Xcode app icon set.
IOS_SIZES = [
    (20, 2, "iphone"), (20, 3, "iphone"),
    (29, 1, "iphone"), (29, 2, "iphone"), (29, 3, "iphone"),
    (40, 2, "iphone"), (40, 3, "iphone"),
    (60, 2, "iphone"), (60, 3, "iphone"),
    (20, 1, "ipad"), (20, 2, "ipad"),
    (29, 1, "ipad"), (29, 2, "ipad"),
    (40, 1, "ipad"), (40, 2, "ipad"),
    (76, 1, "ipad"), (76, 2, "ipad"), (83.5, 2, "ipad"),
    (1024, 1, "ios-marketing"),
]


def load_master() -> Image.Image:
    """Return the emblem as a square RGBA image with a transparent surround."""
    img = None
    for candidate in RASTER_SOURCES:
        if candidate.exists():
            img = Image.open(candidate).convert("RGBA")
            print(f"source: {candidate.relative_to(ROOT)} ({img.width}x{img.height})")
            break

    if img is None:
        import cairosvg  # only needed for the vector fallback

        png = cairosvg.svg2png(url=str(VECTOR_SOURCE), output_width=1024, output_height=1024)
        img = Image.open(io.BytesIO(png)).convert("RGBA")
        print(f"source: {VECTOR_SOURCE.relative_to(ROOT)} (rasterised to 1024x1024)")

    side = max(img.size)
    if img.size != (side, side):
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.alpha_composite(img, ((side - img.width) // 2, (side - img.height) // 2))
        img = square

    # Clip to the circle so no stray background survives around the gold ring.
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, side - 1, side - 1), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(side / 1400))
    img.putalpha(Image.composite(img.getchannel("A"), mask, mask))
    return img


def compose(master: Image.Image, size: int, scale: float, background) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), background)
    inner = max(1, int(round(size * scale)))
    offset = (size - inner) // 2
    canvas.alpha_composite(master.resize((inner, inner), Image.Resampling.LANCZOS), (offset, offset))
    return canvas


def write(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)
    print(f"  wrote {path.relative_to(ROOT)} ({img.width}x{img.height})")


def android(master: Image.Image) -> None:
    print("android launcher icons")
    for folder, size in ANDROID_DENSITIES.items():
        icon = compose(master, size, EMBLEM_SCALE, BACKGROUND)
        write(icon, ANDROID_RES / folder / "launcher_icon.png")
        write(icon, ANDROID_RES / folder / "ic_launcher.png")
        write(
            compose(master, size * 2, FOREGROUND_SCALE, (0, 0, 0, 0)),
            ANDROID_RES / folder / "launcher_icon_foreground.png",
        )

    (ANDROID_RES / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
    (ANDROID_RES / "mipmap-anydpi-v26/launcher_icon.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/launcher_icon_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/launcher_icon_foreground"/>\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )
    (ANDROID_RES / "values").mkdir(parents=True, exist_ok=True)
    (ANDROID_RES / "values/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        f'    <color name="ic_launcher_background">{BACKGROUND_HEX}</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )

    # The old hand-drawn vector would still win on pre-Android 8 devices.
    stale = ANDROID_RES / "mipmap-anydpi"
    if stale.exists():
        shutil.rmtree(stale)
        print("  removed stale mipmap-anydpi vector icon")


def ios(master: Image.Image) -> None:
    print("ios app icons")
    flat = Image.new("RGB", master.size, BACKGROUND[:3])
    flat.paste(master, (0, 0), master)          # iOS icons must not carry alpha
    opaque = flat.convert("RGBA")

    images = []
    rendered = set()
    for point, scale, idiom in IOS_SIZES:
        px = int(round(point * scale))
        name = f"Icon-App-{point:g}x{point:g}@{scale}x.png"
        if name not in rendered:
            write(
                compose(opaque, px, EMBLEM_SCALE, BACKGROUND[:3]).convert("RGB").convert("RGBA"),
                IOS_ICONS / name,
            )
            rendered.add(name)
        images.append({
            "size": f"{point:g}x{point:g}",
            "idiom": idiom,
            "filename": name,
            "scale": f"{scale}x",
        })

    (IOS_ICONS / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"version": 1, "author": "kopitiam-ci"}}, indent=2) + "\n",
        encoding="utf-8",
    )


def web(master: Image.Image) -> None:
    print("web icons")
    write(compose(master, 192, EMBLEM_SCALE, BACKGROUND), WEB / "icons/Icon-192.png")
    write(compose(master, 512, EMBLEM_SCALE, BACKGROUND), WEB / "icons/Icon-512.png")
    write(compose(master, 192, FOREGROUND_SCALE, BACKGROUND), WEB / "icons/Icon-maskable-192.png")
    write(compose(master, 512, FOREGROUND_SCALE, BACKGROUND), WEB / "icons/Icon-maskable-512.png")
    write(compose(master, 64, EMBLEM_SCALE, BACKGROUND), WEB / "favicon.png")


def in_app(master: Image.Image) -> None:
    """Logo shown inside the app, transparent so it sits on any screen colour."""
    print("in-app logo")
    write(master.resize((512, 512), Image.Resampling.LANCZOS), APP_ICONS / "logo_app.png")

    stale_svg = APP_ICONS / "logo_app.svg"
    if stale_svg.exists():
        stale_svg.unlink()
        print("  removed stale logo_app.svg")


def main() -> None:
    master = load_master()
    android(master)
    ios(master)
    web(master)
    in_app(master)
    print("done: semua aset branding dibuat dari logo KOPITIAM")


if __name__ == "__main__":
    main()
