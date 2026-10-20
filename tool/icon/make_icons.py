"""Build every app icon from the leaf "G" of Grammar 3.1.

Source: assets/brand/g_leaf.png, the leaf G on the original splash screen
(Grammar.exe, 2764x1980 JPEG), cut out of its red frame and upscaled 4x
with Real-ESRGAN x4plus. The icon puts it back on a red tile like the original.

    python3 tool/icon/make_icons.py      (needs Pillow)

Writes assets/brand/g_tile.png (in-app mark) and the app icons of
Android, iOS, macOS, Windows, Linux and the web (`--only web` for those alone).
"""
import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
G = Image.open(ROOT / 'assets/brand/g_leaf.png').convert('RGBA')

# Red of the original wooden frame, lighter in the middle.
RED_IN = (178, 22, 28)
RED_OUT = (104, 6, 10)


def background(size: int) -> Image.Image:
    """Radial red gradient, size x size, opaque."""
    n = 256
    mask = Image.radial_gradient('L').resize((n, n))  # 0 at centre, 255 at the rim
    mask = mask.point(lambda v: min(255, int(v * 0.85)))
    img = Image.composite(Image.new('RGB', (n, n), RED_OUT), Image.new('RGB', (n, n), RED_IN), mask)
    return img.resize((size, size), Image.BICUBIC).convert('RGBA')


def leaf_g(height: int) -> Image.Image:
    w = round(G.width * height / G.height)
    return G.resize((w, height), Image.LANCZOS)


def with_shadow(layer: Image.Image, canvas: int, blur: float, offset: int) -> Image.Image:
    """A soft dark shadow under [layer] (same size as the canvas)."""
    alpha = layer.getchannel('A').filter(ImageFilter.GaussianBlur(blur))
    alpha = alpha.point(lambda v: v * 0.55)
    shadow = Image.new('RGBA', (canvas, canvas), (40, 0, 0, 0))
    shadow.putalpha(alpha)
    out = Image.new('RGBA', (canvas, canvas))
    out.alpha_composite(shadow, (0, offset))
    out.alpha_composite(layer)
    return out


def place_g(canvas: int, ratio: float) -> Image.Image:
    """The G centred on a transparent canvas, [ratio] of its height."""
    g = leaf_g(round(canvas * ratio))
    layer = Image.new('RGBA', (canvas, canvas))
    layer.alpha_composite(g, ((canvas - g.width) // 2, (canvas - g.height) // 2))
    return with_shadow(layer, canvas, canvas / 90, round(canvas / 120))


def tile(size: int = 1024, ratio: float = 0.70) -> Image.Image:
    """Full-bleed square: red background + G."""
    img = background(size)
    img.alpha_composite(place_g(size, ratio))
    return img


def rounded(img: Image.Image, radius: float) -> Image.Image:
    s = img.width
    big = Image.new('L', (s * 4, s * 4))
    ImageDraw.Draw(big).rounded_rectangle((0, 0, s * 4 - 1, s * 4 - 1), radius=radius * 4, fill=255)
    out = img.copy()
    out.putalpha(ImageChops.multiply(img.getchannel('A'), big.resize((s, s), Image.LANCZOS)))
    return out


def save(img: Image.Image, rel: str, size: int | None = None, opaque: bool = False) -> None:
    if size:
        img = img.resize((size, size), Image.LANCZOS)
    if opaque:
        img = img.convert('RGB')
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def web_icons(master: Image.Image, rounded_master: Image.Image) -> None:
    """PWA icons (web/manifest.json), the iOS home-screen icon and the favicon."""
    for px in (192, 512):
        save(rounded_master, f'web/icons/Icon-{px}.png', px)
        # Maskable: the platform crops its own shape out of the full tile; the G sits in the safe zone.
        maskable = background(1024)
        maskable.alpha_composite(place_g(1024, 0.50))
        save(maskable, f'web/icons/Icon-maskable-{px}.png', px, opaque=True)
    save(master, 'web/icons/apple-touch-icon.png', 180, opaque=True)  # iOS masks the corners itself
    save(rounded_master, 'web/favicon.png', 64)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--only', choices=['all', 'web'], default='all')
    a = ap.parse_args()
    master = tile()
    rounded_master = rounded(master, 1024 * 0.2)
    web_icons(master, rounded_master)
    if a.only == 'web':
        return

    # In-app mark (top bar); Flutter clips the corners.
    save(master, 'assets/brand/g_tile.png', 192, opaque=True)

    # iOS: square, opaque — the system masks the corners.
    ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for name, px in [('20x20@1x', 20), ('20x20@2x', 40), ('20x20@3x', 60), ('29x29@1x', 29), ('29x29@2x', 58),
                     ('29x29@3x', 87), ('40x40@1x', 40), ('40x40@2x', 80), ('40x40@3x', 120), ('60x60@2x', 120),
                     ('60x60@3x', 180), ('76x76@1x', 76), ('76x76@2x', 152), ('83.5x83.5@2x', 167),
                     ('1024x1024@1x', 1024)]:
        save(master, f'{ios}/Icon-App-{name}.png', px, opaque=True)

    # macOS: 824px rounded rect with a drop shadow on a 1024 canvas (Big Sur grid).
    body = rounded(tile(824), 824 * 0.225)
    a = Image.new('L', (1024, 1024))
    a.paste(body.getchannel('A'), (100, 112))
    mac = Image.new('RGBA', (1024, 1024))
    mac.putalpha(a.filter(ImageFilter.GaussianBlur(14)).point(lambda v: v * 0.35))
    mac.alpha_composite(body, (100, 100))
    for px in (16, 32, 64, 128, 256, 512, 1024):
        save(mac, f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{px}.png', px)

    # Android: legacy launcher icon + adaptive icon (API 26+).
    res = 'android/app/src/main/res'
    for d, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        save(rounded_master, f'{res}/mipmap-{d}/ic_launcher.png', px)
        # Adaptive layers are 108dp; the launcher shows the inner 72dp, the G sits in the 66dp safe zone.
        layer = round(px * 108 / 48)
        save(place_g(1024, 0.50), f'{res}/mipmap-{d}/ic_launcher_foreground.png', layer)
        save(background(1024), f'{res}/mipmap-{d}/ic_launcher_background.png', layer, opaque=True)
    (ROOT / f'{res}/mipmap-anydpi-v26').mkdir(exist_ok=True)
    (ROOT / f'{res}/mipmap-anydpi-v26/ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n', encoding='utf-8')

    # Windows: multi-size .ico, rounded tile.
    win = rounded(master, 1024 * 0.16)
    win.save(ROOT / 'windows/runner/resources/app_icon.ico',
             sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)])

    # Linux: installed as data/app_icon.png next to the binary (linux/CMakeLists.txt), set as the window icon.
    save(rounded_master, 'linux/runner/resources/app_icon.png', 256)


if __name__ == '__main__':
    main()
