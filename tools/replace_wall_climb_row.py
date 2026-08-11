from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from build_normal_atlas import (
    ATLAS_COLUMNS,
    FRAME_SIZE,
    extract_pose,
    fit_pose,
    make_preview,
    occupied_runs,
    paste_centered,
    validate_atlas,
)


WALL_CLIMB_ROW = 2
WALL_CLIMB_FRAMES = 4
TARGET_HEIGHT = 112


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--atlas", type=Path, required=True)
    parser.add_argument("--strip", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    args = parser.parse_args()

    atlas = Image.open(args.atlas).convert("RGBA")
    strip = Image.open(args.strip).convert("RGBA")
    runs = occupied_runs(strip, 0, strip.height)
    if len(runs) != WALL_CLIMB_FRAMES:
        raise ValueError(f"Expected four wall-climb poses, found {len(runs)}: {runs}")

    row_top = WALL_CLIMB_ROW * FRAME_SIZE
    atlas.paste(
        (0, 0, 0, 0),
        (0, row_top, FRAME_SIZE * ATLAS_COLUMNS, row_top + FRAME_SIZE),
    )
    for column, x_bounds in enumerate(runs):
        pose = extract_pose(strip, x_bounds, (0, strip.height))
        pose = fit_pose(pose, TARGET_HEIGHT)
        paste_centered(atlas, pose, column, WALL_CLIMB_ROW)

    validate_atlas(atlas)
    args.atlas.parent.mkdir(parents=True, exist_ok=True)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.atlas)
    make_preview(atlas).save(args.preview)


if __name__ == "__main__":
    main()
