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
    (40, 205),
    (215, 375),
    (380, 545),
    (548, 690),
    (700, 858),
    (858, 1010),
]

# The source supplied seven jump poses, six turn views and seven grand-sweep
# poses. Hold the apex, close the turn on the front view, and hold the maximum
# sweep so all runtime states retain their required eight-frame timing.
SOURCE_SELECTIONS = [
    [0, 1, 2, 3],
    [0, 1, 2, 3],
    [0, 1, 2, 3],
    [0, 1, 2, 3, 3, 4, 5, 6],
    [0, 1, 2, 3, 4, 5, 5, 0],
    [0, 1, 2, 3, 3, 4, 5, 6],
]

EXPECTED_SOURCE_COUNTS = [4, 4, 4, 7, 6, 7]
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
        runs = occupied_runs(source, *band)
        if len(runs) != EXPECTED_SOURCE_COUNTS[row]:
            raise ValueError(
                f"Row {row} expected {EXPECTED_SOURCE_COUNTS[row]} poses, "
                f"found {len(runs)}: {runs}"
            )
        for column, source_index in enumerate(SOURCE_SELECTIONS[row]):
            pose = extract_pose(source, runs[source_index], band)
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
