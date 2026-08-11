from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from build_normal_atlas import (
    ATLAS_COLUMNS,
    ATLAS_ROWS,
    FRAME_SIZE,
    extract_pose,
    fit_pose,
    make_preview,
    occupied_runs,
    paste_centered,
    remove_small_components,
    validate_atlas,
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--atlas", type=Path, required=True)
    parser.add_argument("--strip", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--row", type=int, required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--target-height", type=int, default=96)
    args = parser.parse_args()

    if not 0 <= args.row < ATLAS_ROWS:
        raise ValueError(f"Row must be between 0 and {ATLAS_ROWS - 1}")
    if not 1 <= args.frames <= ATLAS_COLUMNS:
        raise ValueError(f"Frames must be between 1 and {ATLAS_COLUMNS}")

    atlas = Image.open(args.atlas).convert("RGBA")
    strip = Image.open(args.strip).convert("RGBA")
    runs = occupied_runs(strip, 0, strip.height)
    if len(runs) != args.frames:
        raise ValueError(f"Expected {args.frames} poses, found {len(runs)}: {runs}")

    row_top = args.row * FRAME_SIZE
    atlas.paste(
        (0, 0, 0, 0),
        (0, row_top, FRAME_SIZE * ATLAS_COLUMNS, row_top + FRAME_SIZE),
    )
    for column, x_bounds in enumerate(runs):
        pose = extract_pose(strip, x_bounds, (0, strip.height))
        pose = fit_pose(pose, args.target_height)
        pose = remove_small_components(pose, minimum_pixels=24)
        paste_centered(atlas, pose, column, args.row)

    validate_atlas(atlas)
    args.atlas.parent.mkdir(parents=True, exist_ok=True)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.atlas)
    make_preview(atlas).save(args.preview)


if __name__ == "__main__":
    main()
