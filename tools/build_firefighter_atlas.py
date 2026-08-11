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


ROW_BANDS = [
    (12, 206),
    (210, 390),
    (391, 592),
    (600, 747),
    (748, 907),
    (908, 1086),
]

# The recovery axe overlaps the preceding swing by six source pixels, so the
# attack row uses explicit source bounds rather than joining both poses.
ATTACK_RUNS = [
    (31, 193),
    (224, 344),
    (399, 586),
    (592, 699),
]

EXPECTED_SOURCE_COUNTS = [4, 4, 4, 8, 8, 8]
TARGET_HEIGHTS = [96, 96, 112, 96, 96, 96]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    atlas = Image.new(
        "RGBA",
        (FRAME_SIZE * ATLAS_COLUMNS, FRAME_SIZE * ATLAS_ROWS),
        (0, 0, 0, 0),
    )

    for row, band in enumerate(ROW_BANDS):
        runs = ATTACK_RUNS if row == 1 else occupied_runs(source, *band)
        if len(runs) != EXPECTED_SOURCE_COUNTS[row]:
            raise ValueError(
                f"Row {row} expected {EXPECTED_SOURCE_COUNTS[row]} poses, "
                f"found {len(runs)}: {runs}"
            )
        for column, x_bounds in enumerate(runs):
            pose = extract_pose(source, x_bounds, band)
            pose = fit_pose(pose, TARGET_HEIGHTS[row])
            pose = remove_small_components(pose, minimum_pixels=24)
            paste_centered(atlas, pose, column, row)

    validate_atlas(atlas)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.output)
    make_preview(atlas).save(args.preview)


if __name__ == "__main__":
    main()
