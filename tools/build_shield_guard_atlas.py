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
    (5, 185),
    (185, 350),
    (350, 500),
    (498, 650),
    (650, 813),
    (813, 971),
]

# The generated source contains one extra attack recovery and one extra rotation
# view, while jump and special contain seven poses. Select the clearest motion
# arc and hold a readable apex/final guard so the runtime contract stays exact.
SOURCE_SELECTIONS = [
    [0, 1, 2, 3],
    [0, 1, 2, 4],
    [0, 1, 2, 3],
    [0, 1, 2, 3, 3, 4, 5, 6],
    [0, 2, 3, 4, 5, 6, 7, 8],
    [0, 1, 2, 3, 4, 5, 6, 6],
]

EXPECTED_SOURCE_COUNTS = [4, 5, 4, 7, 9, 7]
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
            if row == 3:
                pose = remove_small_components(pose, minimum_pixels=200)
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
