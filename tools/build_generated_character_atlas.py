from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from build_normal_atlas import (
    ATLAS_COLUMNS,
    ATLAS_ROWS,
    FRAME_SIZE,
    fit_pose,
    make_preview,
    occupied_runs,
    paste_centered,
    remove_small_components,
)


EXPECTED_COUNTS = [4, 4, 4, 8, 8, 8]
TARGET_HEIGHTS = [96, 96, 112, 96, 96, 96]


def validate_generated_atlas(atlas: Image.Image) -> None:
    if atlas.size != (1024, 768) or atlas.mode != "RGBA":
        raise ValueError(f"Unexpected atlas format: {atlas.mode} {atlas.size}")
    if not set(atlas.getchannel("A").get_flattened_data()).issubset({0, 255}):
        raise ValueError("Atlas contains partially transparent pixels")
    for row, used_count in enumerate(EXPECTED_COUNTS):
        for column in range(ATLAS_COLUMNS):
            frame = atlas.crop((column * FRAME_SIZE, row * FRAME_SIZE, (column + 1) * FRAME_SIZE, (row + 1) * FRAME_SIZE))
            occupied = frame.getchannel("A").getbbox() is not None
            if occupied != (column < used_count):
                raise ValueError(f"Unexpected frame occupancy: row={row}, column={column}")
            if occupied:
                alpha = frame.getchannel("A")
                border = (
                    list(alpha.crop((0, 0, FRAME_SIZE, 1)).get_flattened_data())
                    + list(alpha.crop((0, FRAME_SIZE - 1, FRAME_SIZE, FRAME_SIZE)).get_flattened_data())
                    + list(alpha.crop((0, 0, 1, FRAME_SIZE)).get_flattened_data())
                    + list(alpha.crop((FRAME_SIZE - 1, 0, FRAME_SIZE, FRAME_SIZE)).get_flattened_data())
                )
                if any(value != 0 for value in border):
                    raise ValueError(f"Frame content touches boundary: row={row}, column={column}")


def occupied_bands(source: Image.Image) -> list[tuple[int, int]]:
    alpha = source.getchannel("A")
    occupied = [alpha.crop((0, y, source.width, y + 1)).getbbox() is not None for y in range(source.height)]
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for y, has_pixel in enumerate(occupied + [False]):
        if has_pixel and start is None:
            start = y
        elif not has_pixel and start is not None:
            runs.append((start, y))
            start = None
    merged: list[tuple[int, int]] = []
    for top, bottom in runs:
        if merged and top - merged[-1][1] <= 4:
            merged[-1] = (merged[-1][0], bottom)
        else:
            merged.append((top, bottom))
    while len(merged) < ATLAS_ROWS:
        split_index = max(range(len(merged)), key=lambda index: merged[index][1] - merged[index][0])
        top, bottom = merged.pop(split_index)
        search_top = top + round((bottom - top) * 0.35)
        search_bottom = top + round((bottom - top) * 0.65)
        split_y = min(
            range(search_top, search_bottom),
            key=lambda y: sum(1 for value in alpha.crop((0, y, source.width, y + 1)).get_flattened_data() if value > 0),
        )
        merged.insert(split_index, (top, split_y))
        merged.insert(split_index + 1, (split_y, bottom))
    return [(max(0, top - 4), min(source.height, bottom + 4)) for top, bottom in merged]


def row_slots(
    source: Image.Image,
    band: tuple[int, int],
    expected_count: int,
) -> list[tuple[int, int]]:
    top, bottom = band
    bounds = source.getchannel("A").crop((0, top, source.width, bottom)).getbbox()
    if bounds is None:
        raise ValueError(f"Empty animation row: {band}")
    left = max(0, bounds[0] - 4)
    right = min(source.width, bounds[2] + 4)
    width = float(right - left)
    return [
        (round(left + width * index / expected_count), round(left + width * (index + 1) / expected_count))
        for index in range(expected_count)
    ]


def extract_frame(source: Image.Image, band: tuple[int, int], run: tuple[int, int]) -> Image.Image:
    left, right = run
    top, bottom = band
    pose = source.crop((max(0, left - 4), top, min(source.width, right + 4), bottom))
    bounds = pose.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"Empty frame: band={band}, run={run}")
    return pose.crop(bounds)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    bands = occupied_bands(source)
    if len(bands) != ATLAS_ROWS:
        raise ValueError(f"Expected {ATLAS_ROWS} animation rows, found {len(bands)}: {bands}")

    atlas = Image.new("RGBA", (FRAME_SIZE * ATLAS_COLUMNS, FRAME_SIZE * ATLAS_ROWS), (0, 0, 0, 0))
    for row, band in enumerate(bands):
        runs = occupied_runs(source, *band)
        if len(runs) != EXPECTED_COUNTS[row]:
            runs = row_slots(source, band, EXPECTED_COUNTS[row])
        for column, run in enumerate(runs):
            pose = extract_frame(source, band, run)
            if row == 1:
                pose = remove_small_components(pose, minimum_pixels=100)
            pose = fit_pose(pose, TARGET_HEIGHTS[row])
            paste_centered(atlas, pose, column, row)

    validate_generated_atlas(atlas)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.output)
    make_preview(atlas).save(args.preview)


if __name__ == "__main__":
    main()
