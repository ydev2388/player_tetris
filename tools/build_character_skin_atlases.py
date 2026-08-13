"""Build fixed-geometry atlases for the seven non-normal character skins.

Each character receives one global scale.  Individual frames are never fitted
or enlarged, and their motion inside each source row is retained.  The final
atlas therefore renders at Sprite2D scale (1, 1) over the shared body collider.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DESIGN_ROOT = ROOT / "design" / "character_skins_v2"
ASSET_ROOT = ROOT / "assets" / "sprites" / "characters"
CHARACTER_IDS = (
    "boxer",
    "shield_guard",
    "firefighter",
    "cleaner",
    "chef",
    "clockmaker",
    "ninja",
)
FRAME_COUNTS = (4, 4, 4, 8, 8, 8)
TILE_SIZE = 128
ALPHA_THRESHOLD = 96
TARGET_STANDING_HEIGHT = 90
SOLE_BASELINE_Y = 109


def hard_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    rgba.putalpha(alpha)
    return rgba


def occupied_intervals(alpha: Image.Image, axis: str) -> list[tuple[int, int]]:
    length = alpha.height if axis == "y" else alpha.width
    used: list[bool] = []
    for index in range(length):
        box = (0, index, alpha.width, index + 1) if axis == "y" else (index, 0, index + 1, alpha.height)
        used.append(alpha.crop(box).getbbox() is not None)
    intervals: list[tuple[int, int]] = []
    start: int | None = None
    for index, is_used in enumerate(used + [False]):
        if is_used and start is None:
            start = index
        elif not is_used and start is not None:
            intervals.append((start, index))
            start = None
    return intervals


def frame_bbox(
    source: Image.Image,
    row_band: tuple[int, int],
    column: int,
) -> tuple[int, int, int, int]:
    left = round(column * source.width / 8)
    right = round((column + 1) * source.width / 8)
    top, bottom = row_band
    bbox = source.crop((left, top, right, bottom)).getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"Missing frame in source row band {row_band}, column {column}")
    return bbox


def build_character(character_id: str) -> tuple[Path, Path]:
    source_path = DESIGN_ROOT / character_id / f"{character_id}_skin_sheet_rgba_v2.png"
    source = hard_alpha(Image.open(source_path))
    row_bands = occupied_intervals(source.getchannel("A"), "y")
    if len(row_bands) != 6:
        raise RuntimeError(f"{character_id}: expected 6 opaque row bands, got {row_bands}")

    idle_bbox = frame_bbox(source, row_bands[0], 0)
    global_scale = TARGET_STANDING_HEIGHT / max(1, idle_bbox[3] - idle_bbox[1])
    atlas = Image.new("RGBA", (1024, 768), (0, 0, 0, 0))

    for row, frame_count in enumerate(FRAME_COUNTS):
        row_top, row_bottom = row_bands[row]
        for column in range(frame_count):
            source_left = round(column * source.width / 8)
            source_right = round((column + 1) * source.width / 8)
            cell_width = source_right - source_left
            local_bbox = frame_bbox(source, row_bands[row], column)
            figure = source.crop(
                (
                    source_left + local_bbox[0],
                    row_top + local_bbox[1],
                    source_left + local_bbox[2],
                    row_top + local_bbox[3],
                )
            )
            output_size = (
                max(1, round(figure.width * global_scale)),
                max(1, round(figure.height * global_scale)),
            )
            figure = figure.resize(output_size, Image.Resampling.NEAREST)

            # Preserve each frame's displacement from its source cell centre.
            source_centre_x = cell_width * 0.5
            paste_x = round(TILE_SIZE * 0.5 + (local_bbox[0] - source_centre_x) * global_scale)
            # Preserve vertical motion relative to the row's shared lower anchor.
            paste_y = round(
                SOLE_BASELINE_Y + 1
                + (local_bbox[1] - (row_bottom - row_top)) * global_scale
            )
            tile = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
            tile.alpha_composite(figure, (paste_x, paste_y))
            if tile.getchannel("A").getbbox() is None:
                raise RuntimeError(f"{character_id}: frame {row + 1}:{column + 1} was clipped away")
            atlas.alpha_composite(tile, (column * TILE_SIZE, row * TILE_SIZE))

    output = ASSET_ROOT / character_id / f"{character_id}_reference_atlas_v2.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output)
    contact = DESIGN_ROOT / character_id / f"{character_id}_contact_sheet_v2.png"
    atlas.resize((4096, 3072), Image.Resampling.NEAREST).save(contact)
    return output, contact


def main() -> None:
    for character_id in CHARACTER_IDS:
        output, contact = build_character(character_id)
        print(output)
        print(contact)


if __name__ == "__main__":
    main()
