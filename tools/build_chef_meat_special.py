"""Build the chef's meat-eating special row on the shared 128px character rig."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DESIGN_DIR = ROOT / "design" / "character_skins_v2" / "chef"
ASSET_DIR = ROOT / "assets" / "sprites" / "characters" / "chef"
SOURCE_PATH = DESIGN_DIR / "chef_meat_atlas_rgba_v4.png"
STRIP_PATH = DESIGN_DIR / "chef_meat_special_strip_rgba_v4.png"
OUTPUT_PATH = ASSET_DIR / "chef_reference_atlas_v7.png"
CONTACT_PATH = DESIGN_DIR / "chef_meat_contact_sheet_v4.png"
BASE_ATLAS_PATH = ASSET_DIR / "chef_reference_atlas_v6.png"
FRAME_COUNT = 8
TILE_SIZE = 128
SPECIAL_ROW_Y = TILE_SIZE * 5
SOLE_BASELINE_Y = 109


def harden_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 255 if alpha >= 64 else 0)
    return rgba


def frame_bounds(strip: Image.Image, column: int) -> tuple[int, int, tuple[int, int, int, int]]:
    left = round(column * strip.width / FRAME_COUNT)
    right = round((column + 1) * strip.width / FRAME_COUNT)
    bounds = strip.crop((left, 0, right, strip.height)).getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"chef meat frame {column + 1} is empty")
    return left, right, bounds


def main() -> None:
    source = harden_alpha(Image.open(SOURCE_PATH))
    row_top = round(source.height * 5 / 6)
    strip = source.crop((0, row_top, source.width, source.height))
    strip.save(STRIP_PATH)

    atlas = Image.open(BASE_ATLAS_PATH).convert("RGBA")
    idle_bounds = atlas.crop((0, 0, TILE_SIZE, TILE_SIZE)).getchannel("A").getbbox()
    if idle_bounds is None:
        raise RuntimeError("chef idle reference frame is empty")
    idle_height = idle_bounds[3] - idle_bounds[1]
    first_left, first_right, first_bounds = frame_bounds(strip, 0)
    first_height = first_bounds[3] - first_bounds[1]
    global_scale = idle_height / max(1, first_height)

    atlas.paste((0, 0, 0, 0), (0, SPECIAL_ROW_Y, atlas.width, SPECIAL_ROW_Y + TILE_SIZE))
    for column in range(FRAME_COUNT):
        left, right, bounds = frame_bounds(strip, column)
        frame = strip.crop((left, 0, right, strip.height))
        figure = frame.crop(bounds)
        output_size = (
            max(1, round(figure.width * global_scale)),
            max(1, round(figure.height * global_scale)),
        )
        figure = figure.resize(output_size, Image.Resampling.NEAREST)
        paste_x = round((TILE_SIZE - figure.width) * 0.5)
        paste_y = SOLE_BASELINE_Y + 1 - figure.height
        tile = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
        tile.alpha_composite(figure, (paste_x, paste_y))
        tile_bounds = tile.getchannel("A").getbbox()
        if tile_bounds is None:
            raise RuntimeError(f"chef meat frame {column + 1} disappeared")
        if (
            tile_bounds[0] <= 0
            or tile_bounds[1] <= 0
            or tile_bounds[2] >= TILE_SIZE
            or tile_bounds[3] >= TILE_SIZE
        ):
            raise RuntimeError(f"chef meat frame {column + 1} touches tile edge: {tile_bounds}")
        atlas.alpha_composite(tile, (column * TILE_SIZE, SPECIAL_ROW_Y))

    atlas.save(OUTPUT_PATH)
    atlas.resize((4096, 3072), Image.Resampling.NEAREST).save(CONTACT_PATH)
    print(OUTPUT_PATH)
    print(STRIP_PATH)
    print(CONTACT_PATH)


if __name__ == "__main__":
    main()
