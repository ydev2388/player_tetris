"""Build one verified 1024x896 character atlas from an ImageGen pose study.

The generated image supplies only the eight bottom-row poses. Existing animation
rows remain byte-for-byte identical to the character's approved source atlas.
The normal v12 bottom row supplies pose height, center and contact-line targets;
the target character's idle height preserves that character's own body scale.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


FRAME_SIZE = 128
FRAME_COUNT = 8
BASE_ROWS_HEIGHT = 768
ATLAS_SIZE = (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE * 7)
ALPHA_THRESHOLD = 96


def _opaque_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    )
    bbox = alpha.getbbox()
    if bbox is None:
        raise AssertionError("frame contains no opaque character pixels")
    return bbox


def _is_chroma_magenta(color: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = color
    return (
        red >= 120
        and blue >= 100
        and green <= 120
        and red - green >= 70
        and blue - green >= 60
    )


def _is_generated_background(color: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = color
    light_checker = min(red, green, blue) >= 220 and max(
        red, green, blue
    ) - min(red, green, blue) <= 20
    return light_checker or _is_chroma_magenta(color)


def _remove_boundary_checker(frame: Image.Image) -> Image.Image:
    """Remove chroma globally, then only boundary-connected light checker."""
    result = frame.convert("RGBA")
    pixels = result.load()
    for pixel_y in range(result.height):
        for pixel_x in range(result.width):
            if _is_chroma_magenta(pixels[pixel_x, pixel_y]):
                pixels[pixel_x, pixel_y] = (0, 0, 0, 0)
    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()
    for pixel_x in range(frame.width):
        queue.extend(((pixel_x, 0), (pixel_x, frame.height - 1)))
    for pixel_y in range(frame.height):
        queue.extend(((0, pixel_y), (frame.width - 1, pixel_y)))
    while queue:
        pixel_x, pixel_y = queue.popleft()
        point = (pixel_x, pixel_y)
        if point in visited:
            continue
        visited.add(point)
        color = pixels[pixel_x, pixel_y]
        if not _is_generated_background(color):
            continue
        pixels[pixel_x, pixel_y] = (0, 0, 0, 0)
        if pixel_x > 0:
            queue.append((pixel_x - 1, pixel_y))
        if pixel_x + 1 < frame.width:
            queue.append((pixel_x + 1, pixel_y))
        if pixel_y > 0:
            queue.append((pixel_x, pixel_y - 1))
        if pixel_y + 1 < frame.height:
            queue.append((pixel_x, pixel_y + 1))
    return result


def _hard_alpha(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    for pixel_y in range(result.height):
        for pixel_x in range(result.width):
            red, green, blue, alpha = pixels[pixel_x, pixel_y]
            pixels[pixel_x, pixel_y] = (
                (red, green, blue, 255)
                if alpha >= ALPHA_THRESHOLD
                else (0, 0, 0, 0)
            )
    return result


def _components(frame: Image.Image) -> list[list[tuple[int, int]]]:
    pixels = frame.load()
    remaining = {
        (pixel_x, pixel_y)
        for pixel_y in range(frame.height)
        for pixel_x in range(frame.width)
        if pixels[pixel_x, pixel_y][3] >= ALPHA_THRESHOLD
    }
    components: list[list[tuple[int, int]]] = []
    while remaining:
        seed = remaining.pop()
        component = [seed]
        queue = [seed]
        for pixel_x, pixel_y in queue:
            for neighbor_y in range(max(0, pixel_y - 1), min(frame.height, pixel_y + 2)):
                for neighbor_x in range(max(0, pixel_x - 1), min(frame.width, pixel_x + 2)):
                    neighbor = (neighbor_x, neighbor_y)
                    if neighbor not in remaining:
                        continue
                    remaining.remove(neighbor)
                    component.append(neighbor)
                    queue.append(neighbor)
        components.append(component)
    return sorted(components, key=len, reverse=True)


def _remove_far_specks(frame: Image.Image) -> Image.Image:
    """Remove tiny remote generator artifacts while retaining real equipment."""
    components = _components(frame)
    if not components:
        raise AssertionError("generated frame is empty after background removal")
    largest = components[0]
    body_left = min(point[0] for point in largest)
    body_top = min(point[1] for point in largest)
    body_right = max(point[0] for point in largest)
    body_bottom = max(point[1] for point in largest)
    pixels = frame.load()
    for component in components[1:]:
        if len(component) > 8:
            continue
        left = min(point[0] for point in component)
        top = min(point[1] for point in component)
        right = max(point[0] for point in component)
        bottom = max(point[1] for point in component)
        horizontal_gap = max(body_left - right, left - body_right, 0)
        vertical_gap = max(body_top - bottom, top - body_bottom, 0)
        if max(horizontal_gap, vertical_gap) <= 6:
            continue
        for pixel_x, pixel_y in component:
            pixels[pixel_x, pixel_y] = (0, 0, 0, 0)
    return frame


def _frame(atlas: Image.Image, row: int, column: int) -> Image.Image:
    return atlas.crop(
        (
            column * FRAME_SIZE,
            row * FRAME_SIZE,
            (column + 1) * FRAME_SIZE,
            (row + 1) * FRAME_SIZE,
        )
    )


def _generated_frame(
    generated: Image.Image,
    frame_index: int,
    layout: str,
) -> Image.Image:
    if layout == "4x2":
        columns = 4
        column = frame_index % columns
        row = frame_index // columns
        search_top = round(generated.height * 0.40)
        search_bottom = round(generated.height * 0.65)
        row_counts: list[tuple[int, int]] = []
        pixels = generated.load()
        for pixel_y in range(search_top, search_bottom):
            content_count = sum(
                1
                for pixel_x in range(generated.width)
                if not _is_generated_background(pixels[pixel_x, pixel_y])
            )
            row_counts.append((content_count, pixel_y))
        minimum_count = min(count for count, _pixel_y in row_counts)
        quiet_rows = [
            pixel_y
            for count, pixel_y in row_counts
            if count <= minimum_count + max(2, generated.width // 1000)
        ]
        split_y = round(sum(quiet_rows) / len(quiet_rows))
    elif layout == "8x7":
        columns = 8
        rows = 7
        column = frame_index
        row = 6
    else:
        raise AssertionError(f"unsupported generated layout: {layout}")
    left = round(column * generated.width / columns)
    right = round((column + 1) * generated.width / columns)
    if layout == "4x2":
        top = 0 if row == 0 else split_y
        bottom = split_y if row == 0 else generated.height
    else:
        top = round(row * generated.height / rows)
        bottom = round((row + 1) * generated.height / rows)
    return generated.crop((left, top, right, bottom))


def _build_frame(
    generated_frame: Image.Image,
    pose_frame: Image.Image,
    body_scale: float,
    frame_index: int,
) -> Image.Image:
    cleaned = _remove_boundary_checker(generated_frame)
    cleaned = _hard_alpha(cleaned)
    cleaned = _remove_far_specks(cleaned)
    generated_bbox = _opaque_bbox(cleaned)
    character = cleaned.crop(generated_bbox)

    pose_bbox = _opaque_bbox(pose_frame)
    pose_height = pose_bbox[3] - pose_bbox[1]
    pose_width = pose_bbox[2] - pose_bbox[0]
    height_scale = pose_height * body_scale / character.height
    # The previous height-only fit enlarged compact crouch/mantle drawings into
    # one-frame giants. Preserve costume/equipment room, but also respect the
    # civilian action silhouette's width envelope.
    equipment_width_allowance = 1.35 if frame_index == 3 else 1.65
    maximum_width = pose_width * body_scale * equipment_width_allowance
    width_scale = maximum_width / character.width
    fit_scale = min(height_scale, width_scale)
    target_width = max(1, round(character.width * fit_scale))
    target_height = max(1, round(character.height * fit_scale))
    character = character.resize((target_width, target_height), Image.Resampling.NEAREST)
    character = _hard_alpha(character)

    pose_center_x = (pose_bbox[0] + pose_bbox[2]) * 0.5
    pose_bottom = pose_bbox[3]
    target_x = round(pose_center_x - character.width * 0.5)
    target_y = pose_bottom - character.height
    if (
        target_x < 0
        or target_y < 0
        or target_x + character.width > FRAME_SIZE
        or target_y + character.height > FRAME_SIZE
    ):
        raise AssertionError(
            "generated pose exceeds its 128x128 cell after scale normalization: "
            f"position=({target_x}, {target_y}), size={character.size}"
        )
    result = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    result.alpha_composite(character, (target_x, target_y))
    return result


def _validate_row(atlas: Image.Image, character_id: str) -> None:
    opaque_counts: list[int] = []
    heights: list[int] = []
    for frame_index in range(FRAME_COUNT):
        frame = _frame(atlas, 6, frame_index)
        bbox = _opaque_bbox(frame)
        opaque_count = sum(
            1
            for alpha in frame.getchannel("A").tobytes()
            if alpha >= ALPHA_THRESHOLD
        )
        components = _components(frame)
        largest_ratio = len(components[0]) / opaque_count
        if largest_ratio < 0.72:
            raise AssertionError(
                f"{character_id} frame {frame_index}: anatomy/equipment is too fragmented "
                f"(largest component ratio={largest_ratio:.3f})"
            )
        if bbox[3] != 112:
            raise AssertionError(
                f"{character_id} frame {frame_index}: contact baseline changed to {bbox[3]}"
            )
        opaque_counts.append(opaque_count)
        heights.append(bbox[3] - bbox[1])

    sorted_counts = sorted(opaque_counts)
    median_count = (sorted_counts[3] + sorted_counts[4]) * 0.5
    for frame_index, opaque_count in enumerate(opaque_counts):
        ratio = opaque_count / median_count
        # Horizontal mantle poses legitimately occupy much more area than tall
        # hanging poses, especially for bulky coats, shields and backpacks.
        # Height and contact-line normalization enforce scale; this guard only
        # rejects a missed/fragmentary extraction or a whole-cell background.
        if not 0.20 <= ratio <= 3.50:
            raise AssertionError(
                f"{character_id} frame {frame_index}: apparent scale changed too much "
                f"(opaque={opaque_count}, median={median_count}, ratio={ratio:.3f})"
            )
    print(f"{character_id}: opaque_pixels={opaque_counts}")
    print(f"{character_id}: visible_heights={heights}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--generated", type=Path, required=True)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--pose-reference", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    parser.add_argument(
        "--generated-layout",
        choices=("4x2", "8x7"),
        default="4x2",
    )
    args = parser.parse_args()

    generated = Image.open(args.generated).convert("RGBA")
    base = Image.open(args.base).convert("RGBA")
    pose_reference = Image.open(args.pose_reference).convert("RGBA")
    if base.size not in ((1024, 768), ATLAS_SIZE):
        raise AssertionError(f"unexpected base atlas size: {base.size}")
    if pose_reference.size != ATLAS_SIZE:
        raise AssertionError(f"unexpected pose reference size: {pose_reference.size}")

    normal_idle_bbox = _opaque_bbox(_frame(pose_reference, 0, 0))
    target_idle_bbox = _opaque_bbox(_frame(base, 0, 0))
    normal_idle_height = normal_idle_bbox[3] - normal_idle_bbox[1]
    target_idle_height = target_idle_bbox[3] - target_idle_bbox[1]
    body_scale = target_idle_height / normal_idle_height

    output = Image.new("RGBA", ATLAS_SIZE, (0, 0, 0, 0))
    output.alpha_composite(base.crop((0, 0, 1024, BASE_ROWS_HEIGHT)), (0, 0))
    for frame_index in range(FRAME_COUNT):
        generated_frame = _generated_frame(
            generated,
            frame_index,
            args.generated_layout,
        )
        pose_frame = _frame(pose_reference, 6, frame_index)
        built_frame = _build_frame(
            generated_frame,
            pose_frame,
            body_scale,
            frame_index,
        )
        output.alpha_composite(built_frame, (frame_index * FRAME_SIZE, BASE_ROWS_HEIGHT))

    if output.crop((0, 0, 1024, BASE_ROWS_HEIGHT)).tobytes() != base.crop(
        (0, 0, 1024, BASE_ROWS_HEIGHT)
    ).tobytes():
        raise AssertionError("existing six animation rows changed")
    _validate_row(output, args.character_id)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output, optimize=False)
    if args.preview:
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        output.crop((0, BASE_ROWS_HEIGHT, 1024, 896)).save(args.preview, optimize=False)
    print(args.output)


if __name__ == "__main__":
    main()
