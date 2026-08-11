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


MAIN_ROW_BANDS = [
    (0, 210),
    (210, 410),
    (410, 575),
    (575, 720),
    (720, 875),
]

MAIN_SOURCE_COUNTS = [4, 4, 4, 7, 8]

# The generated jump row contains seven distinct poses. Hold the apex for one
# extra frame to preserve the planned eight-frame timing without inventing a
# mismatched pose. The rotation row already contains one complete eight-view
# turn.
MAIN_SOURCE_SELECTIONS = [
    [0, 1, 2, 3],
    [0, 1, 2, 3],
    [0, 1, 2, 3],
    [0, 1, 2, 3, 3, 4, 5, 6],
    [0, 1, 2, 3, 4, 5, 6, 7],
]

SPECIAL_ROW_BANDS = [(0, 500), (500, 1024)]
TARGET_HEIGHTS = [96, 96, 112, 96, 96, 96]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--special-input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    special_source = Image.open(args.special_input).convert("RGBA")
    atlas = Image.new(
        "RGBA",
        (FRAME_SIZE * ATLAS_COLUMNS, FRAME_SIZE * ATLAS_ROWS),
        (0, 0, 0, 0),
    )

    for row, band in enumerate(MAIN_ROW_BANDS):
        runs = occupied_runs(source, *band)
        if len(runs) != MAIN_SOURCE_COUNTS[row]:
            raise ValueError(
                f"Row {row} expected {MAIN_SOURCE_COUNTS[row]} poses, "
                f"found {len(runs)}: {runs}"
            )
        for column, source_index in enumerate(MAIN_SOURCE_SELECTIONS[row]):
            pose = extract_pose(source, runs[source_index], band)
            if row == 2:
                # The following jump row's toque tips slightly cross the wall
                # band's source boundary. They are isolated from the climber,
                # so remove them before scaling to avoid stray white pixels.
                pose = remove_small_components(pose, minimum_pixels=1000)
            pose = fit_pose(pose, TARGET_HEIGHTS[row])
            pose = remove_small_components(pose, minimum_pixels=24)
            paste_centered(atlas, pose, column, row)

    special_column = 0
    for band in SPECIAL_ROW_BANDS:
        runs = occupied_runs(special_source, *band)
        if len(runs) != 4:
            raise ValueError(f"Special band {band} expected 4 poses, found {len(runs)}: {runs}")
        for run in runs:
            pose = extract_pose(special_source, run, band)
            pose = fit_pose(pose, TARGET_HEIGHTS[5])
            pose = remove_small_components(pose, minimum_pixels=24)
            paste_centered(atlas, pose, special_column, 5)
            special_column += 1

    validate_atlas(atlas)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.output)
    make_preview(atlas).save(args.preview)


if __name__ == "__main__":
    main()
