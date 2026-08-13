from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ATLAS_SIZE = (1024, 768)
CELL_SIZE = 128
GRID_COLUMNS = 8
GRID_ROWS = 6
ALPHA_THRESHOLD = 128
CHARACTERS = (
    "normal",
    "boxer",
    "shield_guard",
    "firefighter",
    "chef",
    "clockmaker",
    "ninja",
)
ALL_CHARACTERS = (*CHARACTERS, "cleaner")
PROPORTION_PRESERVED_CHARACTERS = set(CHARACTERS)
PROPORTION_PRESERVED_FRAME_INDICES = {*range(16, 20), *range(24, 32)}


def alpha_bbox(image: Image.Image, threshold: int = ALPHA_THRESHOLD):
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= threshold else 0)
    return mask.getbbox()


def ensure_full_bounds(image: Image.Image) -> None:
    width, height = image.size
    pixels = image.load()
    opaque = [
        (x, y)
        for y in range(height)
        for x in range(width)
        if pixels[x, y][3] >= ALPHA_THRESHOLD
    ]
    if not opaque:
        raise RuntimeError("normalized frame became empty")

    min_x = min(point[0] for point in opaque)
    max_x = max(point[0] for point in opaque)
    min_y = min(point[1] for point in opaque)
    max_y = max(point[1] for point in opaque)
    left_point = next(point for point in opaque if point[0] == min_x)
    right_point = next(point for point in opaque if point[0] == max_x)
    top_point = next(point for point in opaque if point[1] == min_y)
    bottom_point = next(point for point in opaque if point[1] == max_y)

    for x in range(0, min_x):
        pixels[x, left_point[1]] = pixels[left_point]
    for x in range(max_x + 1, width):
        pixels[x, right_point[1]] = pixels[right_point]
    for y in range(0, min_y):
        pixels[top_point[0], y] = pixels[top_point]
    for y in range(max_y + 1, height):
        pixels[bottom_point[0], y] = pixels[bottom_point]


def resize_sources(work_dir: Path) -> None:
    for character in CHARACTERS:
        source_path = work_dir / f"{character}_imagegen_source.png"
        output_path = work_dir / f"{character}_imagegen_1024_chroma.png"
        with Image.open(source_path) as source:
            rgba = source.convert("RGBA")
            resized = rgba.resize(ATLAS_SIZE, Image.Resampling.NEAREST)
            resized.save(output_path)
        print(f"prepared {character}: {source_path.name} -> {output_path.name}")


def normalize_atlas(reference: Image.Image, target: Image.Image) -> tuple[Image.Image, int]:
    output = Image.new("RGBA", ATLAS_SIZE, (0, 0, 0, 0))
    used_frames = 0

    for row in range(GRID_ROWS):
        for column in range(GRID_COLUMNS):
            left = column * CELL_SIZE
            top = row * CELL_SIZE
            cell_box = (left, top, left + CELL_SIZE, top + CELL_SIZE)
            reference_cell = reference.crop(cell_box)
            target_cell = target.crop(cell_box)
            reference_bbox = alpha_bbox(reference_cell)
            target_bbox = alpha_bbox(target_cell)

            if reference_bbox is None:
                continue
            if target_bbox is None:
                raise RuntimeError(f"missing generated frame at row={row}, column={column}")

            used_frames += 1
            reference_width = reference_bbox[2] - reference_bbox[0]
            reference_height = reference_bbox[3] - reference_bbox[1]

            # Crop to the generated frame's opaque silhouette, scale with nearest-neighbour
            # sampling, and place it in the exact opaque-pixel bounds of the cleaner frame.
            # A binary alpha mask keeps pixel-art edges crisp and makes the source geometry
            # deterministic for collision/visual regression checks.
            cropped = target_cell.crop(target_bbox).convert("RGBA")
            resized = cropped.resize((reference_width, reference_height), Image.Resampling.NEAREST)
            pixels = resized.load()
            for y in range(reference_height):
                for x in range(reference_width):
                    red, green, blue, alpha = pixels[x, y]
                    pixels[x, y] = (red, green, blue, 255 if alpha >= ALPHA_THRESHOLD else 0)
            ensure_full_bounds(resized)

            output.alpha_composite(
                resized,
                (left + reference_bbox[0], top + reference_bbox[1]),
            )

    return output, used_frames


def normalize_all(project_dir: Path, work_dir: Path, output_dir: Path) -> None:
    reference_path = (
        project_dir / "assets" / "sprites" / "characters" / "cleaner" / "cleaner_atlas.png"
    )
    with Image.open(reference_path) as image:
        reference = image.convert("RGBA")
        if reference.size != ATLAS_SIZE:
            raise RuntimeError(f"unexpected cleaner atlas size: {reference.size}")

        output_dir.mkdir(parents=True, exist_ok=True)
        for character in CHARACTERS:
            keyed_path = work_dir / f"{character}_atlas_keyed.png"
            with Image.open(keyed_path) as image:
                target = image.convert("RGBA")
                if target.size != ATLAS_SIZE:
                    raise RuntimeError(f"unexpected {character} atlas size: {target.size}")
                normalized, used_frames = normalize_atlas(reference, target)
                if used_frames != 36:
                    raise RuntimeError(f"unexpected {character} frame count: {used_frames}")
                output_path = output_dir / f"{character}_atlas.png"
                normalized.save(output_path)
                print(f"normalized {character}: {used_frames} frames -> {output_path}")


def validate_assets(project_dir: Path) -> None:
    character_dir = project_dir / "assets" / "sprites" / "characters"
    reference_path = character_dir / "cleaner" / "cleaner_atlas.png"
    with Image.open(reference_path) as image:
        reference = image.convert("RGBA")
        reference_boxes = []
        for row in range(GRID_ROWS):
            for column in range(GRID_COLUMNS):
                left = column * CELL_SIZE
                top = row * CELL_SIZE
                reference_boxes.append(
                    alpha_bbox(reference.crop((left, top, left + CELL_SIZE, top + CELL_SIZE)))
                )

    expected_used = sum(box is not None for box in reference_boxes)
    if expected_used != 36:
        raise RuntimeError(f"unexpected cleaner frame count: {expected_used}")

    checked_frames = 0
    for character in ALL_CHARACTERS:
        atlas_path = character_dir / character / f"{character}_atlas.png"
        with Image.open(atlas_path) as image:
            atlas = image.convert("RGBA")
            if atlas.size != ATLAS_SIZE:
                raise RuntimeError(f"unexpected {character} atlas size: {atlas.size}")
            frame_index = 0
            for row in range(GRID_ROWS):
                for column in range(GRID_COLUMNS):
                    left = column * CELL_SIZE
                    top = row * CELL_SIZE
                    target_box = alpha_bbox(
                        atlas.crop((left, top, left + CELL_SIZE, top + CELL_SIZE))
                    )
                    reference_box = reference_boxes[frame_index]
                    preserves_motion_proportions = (
                        character in PROPORTION_PRESERVED_CHARACTERS
                        and frame_index in PROPORTION_PRESERVED_FRAME_INDICES
                    )
                    if preserves_motion_proportions and target_box is None:
                        raise RuntimeError(
                            f"{character} proportion-preserved frame {frame_index} is empty"
                        )
                    if not preserves_motion_proportions and target_box != reference_box:
                        raise RuntimeError(
                            f"{character} frame {frame_index} bounds {target_box} "
                            f"do not match cleaner {reference_box}"
                        )
                    if reference_box is not None:
                        checked_frames += 1
                    frame_index += 1
        print(f"validated {character}: 1024x768 RGBA, 36 valid motion frames")
    print(f"validated total: {checked_frames} used frames")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("prepare", "normalize", "validate"))
    parser.add_argument("--project-dir", type=Path, default=Path.cwd())
    parser.add_argument("--work-dir", type=Path, default=Path("build/sprite_rebuild"))
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()

    project_dir = args.project_dir.resolve()
    work_dir = args.work_dir.resolve()
    if args.mode == "prepare":
        resize_sources(work_dir)
        return

    if args.mode == "validate":
        validate_assets(project_dir)
        return

    output_dir = (args.output_dir or work_dir / "normalized").resolve()
    normalize_all(project_dir, work_dir, output_dir)


if __name__ == "__main__":
    main()
