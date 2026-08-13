"""Build the versioned normal-character reference atlas from reviewed ImageGen rows.

The important constraint is that every frame in a row shares one scale.  Pose
silhouettes are never normalized independently, so crouches and tucks stay small.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "design" / "character_reference" / "normal_v2" / "rows"
ATLAS_PATH = (
    ROOT
    / "assets"
    / "sprites"
    / "characters"
    / "normal"
    / "normal_reference_atlas_v2.png"
)
CONTACT_SHEET_PATH = (
    ROOT
    / "design"
    / "character_reference"
    / "normal_v2"
    / "normal_reference_contact_sheet_v2.png"
)

TILE_SIZE = 128
ATLAS_COLUMNS = 8
ATLAS_ROWS = 6
ALPHA_THRESHOLD = 96


@dataclass(frozen=True)
class RowSpec:
    frames: int
    scale: float
    anchor_mode: str
    source_ground_y: int = 0
    root_fraction: float = 0.56
    root_target_y: int = 70
    boundaries: tuple[int, ...] = ()


# Each scale is derived once from the reviewed source strip's standing body.
# It is deliberately shared by every frame in that strip.
ROW_SPECS = (
    RowSpec(4, 90.0 / 506.0, "source_ground", source_ground_y=703),
    RowSpec(4, 90.0 / 451.0, "source_ground", source_ground_y=684),
    RowSpec(4, 90.0 / 468.0, "source_ground", source_ground_y=638),
    RowSpec(8, 90.0 / 358.0, "pelvis", root_fraction=0.57, root_target_y=71),
    RowSpec(8, 90.0 / 366.0, "pelvis", root_fraction=0.56),
    # Speed streaks are detached opaque clusters, so use reviewed per-frame
    # boundaries instead of naïvely cutting this strip into equal widths.
    RowSpec(
        8,
        90.0 / 337.0,
        "pelvis",
        root_fraction=0.56,
        boundaries=(0, 230, 440, 760, 1025, 1270, 1605, 1800, 2006),
    ),
)


def hard_alpha(image: Image.Image) -> Image.Image:
    """Remove chroma-key fringe alpha while preserving generated RGB pixels."""
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    rgba.putalpha(alpha)
    return rgba


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Generated frame contains no opaque pixels")
    return bbox


def build_frame(
    source: Image.Image,
    segment_left: int,
    segment_right: int,
    spec: RowSpec,
) -> Image.Image:
    segment = source.crop((segment_left, 0, segment_right, source.height))
    bbox = alpha_bbox(segment)
    figure = segment.crop(bbox)
    output_size = (
        max(1, round(figure.width * spec.scale)),
        max(1, round(figure.height * spec.scale)),
    )
    figure = figure.resize(output_size, Image.Resampling.NEAREST)

    # Horizontal source-cell centres are the shared animation roots.  This keeps
    # punches and speed poses from being re-centred by their wider silhouettes.
    segment_center = (segment_right - segment_left) * 0.5
    paste_x = round(TILE_SIZE * 0.5 + (bbox[0] - segment_center) * spec.scale)

    if spec.anchor_mode == "source_ground":
        # Pixel row 109 is the common sole baseline (bbox end is therefore 110).
        paste_y = round(110 + (bbox[1] - spec.source_ground_y) * spec.scale)
    else:
        source_root_y = bbox[1] + (bbox[3] - bbox[1]) * spec.root_fraction
        paste_y = round(spec.root_target_y - (source_root_y - bbox[1]) * spec.scale)

    tile = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    tile.alpha_composite(figure, (paste_x, paste_y))
    if tile.getchannel("A").getbbox() is None:
        raise RuntimeError("Frame was placed outside its 128x128 tile")
    return tile


def main() -> None:
    atlas = Image.new(
        "RGBA",
        (TILE_SIZE * ATLAS_COLUMNS, TILE_SIZE * ATLAS_ROWS),
        (0, 0, 0, 0),
    )

    for row_index, spec in enumerate(ROW_SPECS):
        source = hard_alpha(Image.open(SOURCE_DIR / f"row_{row_index + 1}_rgba.png"))
        for frame_index in range(spec.frames):
            if spec.boundaries:
                left = spec.boundaries[frame_index]
                right = spec.boundaries[frame_index + 1]
            else:
                left = round(frame_index * source.width / spec.frames)
                right = round((frame_index + 1) * source.width / spec.frames)
            tile = build_frame(source, left, right, spec)
            atlas.alpha_composite(tile, (frame_index * TILE_SIZE, row_index * TILE_SIZE))

    ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(ATLAS_PATH)

    # A 4x nearest-neighbour contact sheet is kept as design QA evidence.
    CONTACT_SHEET_PATH.parent.mkdir(parents=True, exist_ok=True)
    contact = atlas.resize((atlas.width * 4, atlas.height * 4), Image.Resampling.NEAREST)
    contact.save(CONTACT_SHEET_PATH)
    print(ATLAS_PATH)
    print(CONTACT_SHEET_PATH)


if __name__ == "__main__":
    main()
