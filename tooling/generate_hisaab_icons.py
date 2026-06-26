from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]

ACCENT = (0, 150, 136)
ACCENT_LIGHT = (77, 182, 172)
INK = (27, 42, 74)
WHITE = (255, 255, 255)


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf"),
        Path("C:/Windows/Fonts/calibrib.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _mix(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def _rounded_gradient(size: int, rounded: bool = True) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / max(1, (size - 1) * 2)
            r = _mix(ACCENT[0], ACCENT_LIGHT[0], t)
            g = _mix(ACCENT[1], ACCENT_LIGHT[1], t)
            b = _mix(ACCENT[2], ACCENT_LIGHT[2], t)
            pixels[x, y] = (r, g, b, 255)

    if not rounded:
        return image

    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    radius = round(size * 0.23)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    image.putalpha(mask)
    return image


def make_logo(size: int, *, maskable: bool = False) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rounded = not maskable
    tile = _rounded_gradient(size, rounded=rounded)

    if maskable:
        # Keep the mark inside Android's maskable icon safe area.
        safe = round(size * 0.10)
        mark = make_logo(size - safe * 2, maskable=False)
        canvas.paste(tile, (0, 0), tile)
        canvas.alpha_composite(mark, (safe, safe))
        return canvas

    canvas.alpha_composite(tile)
    draw = ImageDraw.Draw(canvas)

    stroke_book = max(1, round(size * 0.055))
    stroke_rupee = max(1, round(size * 0.045))

    left = size * 0.23
    top = size * 0.22
    right = size * 0.77
    bottom = size * 0.78
    center = size * 0.50

    book_points = [
        (left, top),
        (left, bottom),
        (center, size * 0.68),
        (right, bottom),
        (right, top),
    ]
    draw.line(
        book_points,
        fill=(255, 255, 255, 48),
        width=stroke_book,
        joint="curve",
    )

    draw.line(
        [(size * 0.37, size * 0.32), (size * 0.65, size * 0.32)],
        fill=(255, 255, 255, 232),
        width=stroke_rupee,
    )
    draw.line(
        [(size * 0.37, size * 0.43), (size * 0.60, size * 0.43)],
        fill=(255, 255, 255, 232),
        width=stroke_rupee,
    )

    font = _font(round(size * 0.47))
    text = "H"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (size - text_w) / 2 - bbox[0]
    y = (size - text_h) / 2 - bbox[1] + size * 0.035
    draw.text((x, y), text, fill=WHITE, font=font)

    return canvas


def save_png(path: Path, size: int, *, maskable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    make_logo(size, maskable=maskable).save(path)


def _scale_px(size_value: str, scale_value: str) -> int:
    points = float(size_value.split("x", 1)[0])
    scale = int(scale_value.replace("x", ""))
    return round(points * scale)


def save_xcassets(app_icon_dir: Path) -> None:
    contents = json.loads((app_icon_dir / "Contents.json").read_text())
    for image in contents["images"]:
        filename = image.get("filename")
        if not filename:
            continue
        pixels = _scale_px(image["size"], image["scale"])
        save_png(app_icon_dir / filename, pixels)


def main() -> None:
    for density, pixels in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        save_png(
            ROOT / "android" / "app" / "src" / "main" / "res" / density / "ic_launcher.png",
            pixels,
        )

    save_xcassets(ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset")
    save_xcassets(ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset")

    save_png(ROOT / "web" / "favicon.png", 32)
    save_png(ROOT / "web" / "icons" / "Icon-192.png", 192)
    save_png(ROOT / "web" / "icons" / "Icon-512.png", 512)
    save_png(ROOT / "web" / "icons" / "Icon-maskable-192.png", 192, maskable=True)
    save_png(ROOT / "web" / "icons" / "Icon-maskable-512.png", 512, maskable=True)

    ico_sizes = [16, 32, 48, 64, 128, 256]
    ico_images = [make_logo(size).convert("RGBA") for size in ico_sizes]
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    ico_images[-1].save(ico_path, format="ICO", sizes=[(size, size) for size in ico_sizes])

    print("Generated HISAAB app icons.")


if __name__ == "__main__":
    main()
