from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


FRAME_SIZE = 128
ATLAS_COLUMNS = 8
ATLAS_ROWS = 6

# Bounds of the six animation bands in the selected C-design source image.
ROW_BANDS = [
    (12, 206),
    (210, 390),
    (391, 592),
    (593, 747),
    (748, 907),
    (908, 1086),
]

# ImageGen supplied seven distinct rotation views. The final guard view is held
# for one frame to close the turn cleanly without inventing a mismatched pose.
SOURCE_SELECTIONS = [
    [0, 1, 2, 3],
    [0, 1, 2, 3],
    [0, 1, 2, 3],
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 2, 3, 4, 5, 6, 0],
    [0, 1, 2, 3, 4, 5, 6, 7],
]

TARGET_HEIGHTS = [96, 96, 112, 96, 96, 96]


def occupied_runs(image: Image.Image, top: int, bottom: int) -> list[tuple[int, int]]:
    alpha = image.getchannel("A")
    occupied: list[bool] = []
    for x in range(image.width):
        column = alpha.crop((x, top, x + 1, bottom))
        occupied.append(column.getbbox() is not None)

    runs: list[tuple[int, int]] = []
    start: int | None = None
    for x, has_pixel in enumerate(occupied + [False]):
        if has_pixel and start is None:
            start = x
        elif not has_pixel and start is not None:
            runs.append((start, x))
            start = None

    merged: list[tuple[int, int]] = []
    for left, right in runs:
        if merged and left - merged[-1][1] <= 8:
            merged[-1] = (merged[-1][0], right)
        else:
            merged.append((left, right))

    filtered: list[tuple[int, int]] = []
    for left, right in merged:
        band = alpha.crop((left, top, right, bottom))
        opaque_pixels = sum(1 for value in band.get_flattened_data() if value > 0)
        if opaque_pixels >= 500:
            filtered.append((left, right))
    return filtered


def remove_small_components(pose: Image.Image, minimum_pixels: int = 24) -> Image.Image:
    alpha = pose.getchannel("A")
    width, height = pose.size
    opaque = alpha.load()
    visited: set[tuple[int, int]] = set()
    remove: list[tuple[int, int]] = []

    for y in range(height):
        for x in range(width):
            if opaque[x, y] == 0 or (x, y) in visited:
                continue
            stack = [(x, y)]
            component: list[tuple[int, int]] = []
            visited.add((x, y))
            while stack:
                current_x, current_y = stack.pop()
                component.append((current_x, current_y))
                for next_x, next_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if not (0 <= next_x < width and 0 <= next_y < height):
                        continue
                    if opaque[next_x, next_y] == 0 or (next_x, next_y) in visited:
                        continue
                    visited.add((next_x, next_y))
                    stack.append((next_x, next_y))
            if len(component) < minimum_pixels:
                remove.extend(component)

    pixels = pose.load()
    for x, y in remove:
        pixels[x, y] = (0, 0, 0, 0)
    bounds = pose.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Pose became empty after component cleanup")
    return pose.crop(bounds)


def extract_pose(
    image: Image.Image,
    x_bounds: tuple[int, int],
    y_bounds: tuple[int, int],
) -> Image.Image:
    left, right = x_bounds
    top, bottom = y_bounds
    pose = image.crop((left, top, right, bottom))
    alpha_bounds = pose.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise ValueError(f"Empty pose at x={x_bounds}, y={y_bounds}")
    return remove_small_components(pose.crop(alpha_bounds))


def fit_pose(pose: Image.Image, target_height: int) -> Image.Image:
    scale = target_height / pose.height
    if pose.width * scale > FRAME_SIZE - 8:
        scale = (FRAME_SIZE - 8) / pose.width
    target = (
        max(1, round(pose.width * scale)),
        max(1, round(pose.height * scale)),
    )
    resized = pose.resize(target, Image.Resampling.NEAREST)
    pixels = resized.load()
    for y in range(resized.height):
        for x in range(resized.width):
            red, green, blue, alpha_value = pixels[x, y]
            pixels[x, y] = (red, green, blue, 255 if alpha_value >= 128 else 0)
    return resized


def paste_centered(atlas: Image.Image, pose: Image.Image, column: int, row: int) -> None:
    x = column * FRAME_SIZE + (FRAME_SIZE - pose.width) // 2
    y = row * FRAME_SIZE + (FRAME_SIZE - pose.height) // 2
    atlas.alpha_composite(pose, (x, y))


def make_preview(atlas: Image.Image) -> Image.Image:
    preview = Image.new("RGBA", atlas.size, (20, 22, 28, 255))
    checker = Image.new("RGBA", atlas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(checker)
    tile = 16
    for y in range(0, atlas.height, tile):
        for x in range(0, atlas.width, tile):
            color = (34, 37, 46, 255) if (x // tile + y // tile) % 2 else (27, 30, 38, 255)
            draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=color)
    preview.alpha_composite(checker)
    preview.alpha_composite(atlas)
    grid = ImageDraw.Draw(preview)
    for x in range(0, preview.width + 1, FRAME_SIZE):
        grid.line((x, 0, x, preview.height), fill=(80, 86, 104, 180), width=1)
    for y in range(0, preview.height + 1, FRAME_SIZE):
        grid.line((0, y, preview.width, y), fill=(80, 86, 104, 180), width=1)
    return preview


def validate_atlas(atlas: Image.Image) -> None:
    if atlas.size != (1024, 768) or atlas.mode != "RGBA":
        raise ValueError(f"Unexpected atlas format: {atlas.mode} {atlas.size}")
    alpha_values = set(atlas.getchannel("A").get_flattened_data())
    if not alpha_values.issubset({0, 255}):
        raise ValueError(f"Atlas contains partial alpha values: {sorted(alpha_values)}")
    for corner in (
        (0, 0),
        (atlas.width - 1, 0),
        (0, atlas.height - 1),
        (atlas.width - 1, atlas.height - 1),
    ):
        if atlas.getpixel(corner)[3] != 0:
            raise ValueError(f"Atlas corner is not transparent: {corner}")

    used_counts = [4, 4, 4, 8, 8, 8]
    for row, used_count in enumerate(used_counts):
        for column in range(ATLAS_COLUMNS):
            frame = atlas.crop(
                (
                    column * FRAME_SIZE,
                    row * FRAME_SIZE,
                    (column + 1) * FRAME_SIZE,
                    (row + 1) * FRAME_SIZE,
                )
            )
            bounds = frame.getchannel("A").getbbox()
            if column >= used_count:
                if bounds is not None:
                    raise ValueError(f"Unused frame is not empty: row={row}, column={column}")
                continue
            if bounds is None:
                raise ValueError(f"Used frame is empty: row={row}, column={column}")
            core = frame.getchannel("A").crop((50, 32, 78, 96))
            core_pixels = sum(1 for value in core.get_flattened_data() if value == 255)
            if core_pixels < 20:
                raise ValueError(
                    f"Frame has no reliable central crush silhouette: row={row}, column={column}"
                )


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

    expected_source_counts = [4, 4, 4, 8, 7, 8]
    for row, band in enumerate(ROW_BANDS):
        runs = occupied_runs(source, *band)
        if len(runs) != expected_source_counts[row]:
            raise ValueError(
                f"Row {row} expected {expected_source_counts[row]} poses, found {len(runs)}: {runs}"
            )
        for column, source_index in enumerate(SOURCE_SELECTIONS[row]):
            pose = extract_pose(source, runs[source_index], band)
            pose = fit_pose(pose, TARGET_HEIGHTS[row])
            paste_centered(atlas, pose, column, row)

    validate_atlas(atlas)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.output)
    make_preview(atlas).save(args.preview)


if __name__ == "__main__":
    main()
