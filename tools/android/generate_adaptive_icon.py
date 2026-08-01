#!/usr/bin/env python3
"""Génère les calques de l'icône adaptative Android à partir du logo source.

Android 8+ compose l'icône à partir de deux calques de 108 dp dont seuls les
72 dp centraux sont garantis visibles (le masque du constructeur rogne le
reste). Le logo est donc réduit dans cette zone de sécurité plutôt que d'être
étiré sur toute la toile.

Trois calques sont produits :

* ``ic_launcher_foreground`` — le logo couleur sur fond transparent ;
* ``ic_launcher_monochrome`` — la silhouette du logo, détails évidés, pour les
  icônes thématiques d'Android 13+ (le système applique sa propre teinte) ;
* le fond, déclaré en couleur unie dans ``values/ic_launcher_background.xml``.

Usage :

    python3 tools/android/generate_adaptive_icon.py
"""

from __future__ import annotations

import pathlib

from PIL import Image

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = REPO_ROOT / "assets/images/logo_ilipresto.png"
RES_DIR = REPO_ROOT / "android/app/src/main/res"

# Toile de 108 dp convertie en pixels pour chaque densité.
DENSITIES = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}

# Part de la toile occupée par le logo. La zone garantie visible est de
# 72/108 ; on reste légèrement en deçà pour que les masques les plus agressifs
# (cercle, goutte) ne rognent pas les angles du carré arrondi.
SAFE_RATIO = 66 / 108

# Seuil de « blanc » utilisé pour évider les détails du visage en monochrome.
WHITE_THRESHOLD = 225


def load_source() -> Image.Image:
    image = Image.open(SOURCE).convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    return image.crop(bbox) if bbox else image


def build_monochrome(logo: Image.Image) -> Image.Image:
    """Silhouette opaque du logo, détails clairs rendus transparents."""
    pixels = logo.load()
    width, height = logo.size
    mono = Image.new("RGBA", logo.size, (0, 0, 0, 0))
    mono_pixels = mono.load()

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            is_light = r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD
            mono_pixels[x, y] = (0, 0, 0, 0) if is_light else (0, 0, 0, a)

    return mono


def render_layer(logo: Image.Image, canvas_px: int) -> Image.Image:
    target = max(1, round(canvas_px * SAFE_RATIO))
    scaled = logo.copy()
    scaled.thumbnail((target, target), Image.LANCZOS)

    canvas = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
    canvas.alpha_composite(
        scaled,
        (
            (canvas_px - scaled.width) // 2,
            (canvas_px - scaled.height) // 2,
        ),
    )
    return canvas


def main() -> None:
    logo = load_source()
    monochrome = build_monochrome(logo)

    for density, canvas_px in DENSITIES.items():
        target_dir = RES_DIR / f"mipmap-{density}"
        target_dir.mkdir(parents=True, exist_ok=True)

        render_layer(logo, canvas_px).save(
            target_dir / "ic_launcher_foreground.png"
        )
        render_layer(monochrome, canvas_px).save(
            target_dir / "ic_launcher_monochrome.png"
        )
        print(f"mipmap-{density}: {canvas_px}x{canvas_px}")

    # Icône 512x512 attendue par la fiche Play Console.
    store_icon = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
    scaled = logo.copy()
    scaled.thumbnail((512, 512), Image.LANCZOS)
    store_icon.alpha_composite(
        scaled,
        ((512 - scaled.width) // 2, (512 - scaled.height) // 2),
    )
    store_dir = REPO_ROOT / "marketing/play-store/graphics"
    store_dir.mkdir(parents=True, exist_ok=True)
    store_icon.convert("RGB").save(store_dir / "icon-512.png")
    print("marketing/play-store/graphics/icon-512.png: 512x512")


if __name__ == "__main__":
    main()
