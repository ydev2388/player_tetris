"""Build the civilian's eight-phase alternating-leg wall-climb row.

The reviewed 4x2 ImageGen source is read left-to-right, top row first.  Each
complete body pose is normalized as one unit so the hips, knees, calves and
feet move together.  Hands remain on one authored wall-contact edge and the
fixed gameplay collider is never changed.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (
    ROOT
    / "design"
    / "character_reference"
    / "wall_climb"
    / "normal_wall_climb_alternating_8_source_v5_rgba.png"
)
ATLAS_SOURCE = (
    ROOT
    / "assets"
    / "sprites"
    / "characters"
    / "normal"
    / "normal_reference_atlas_v6.png"
)
ATLAS_OUTPUT = ATLAS_SOURCE.with_name("normal_reference_atlas_v7.png")
PREVIEW_OUTPUT = ROOT / "build" / "normal_climb_v7_8_frames.png"

FRAME_SIZE = 128
SOURCE_COLUMNS = 4
SOURCE_ROWS = 2
FRAME_COUNT = SOURCE_COLUMNS * SOURCE_ROWS
TARGET_HEIGHT = 100
TARGET_FORWARD_EDGE_X = 87
TARGET_TOP_Y = 10
PREVIEW_SCALE = 3


def hard_alpha(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 255 if alpha >= 128 else 0)
    return result


def largest_connected_subject(image: Image.Image) -> Image.Image:
    """Keep the complete character while discarding neighboring-pose slivers."""

    source = hard_alpha(image)
    opaque = source.getchannel("A").load()
    visited: set[tuple[int, int]] = set()
    largest: list[tuple[int, int]] = []
    for y in range(source.height):
        for x in range(source.width):
            if opaque[x, y] == 0 or (x, y) in visited:
                continue
            component: list[tuple[int, int]] = []
            stack = [(x, y)]
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
                    if not (0 <= next_x < source.width and 0 <= next_y < source.height):
                        continue
                    if opaque[next_x, next_y] == 0 or (next_x, next_y) in visited:
                        continue
                    visited.add((next_x, next_y))
                    stack.append((next_x, next_y))
            if len(component) > len(largest):
                largest = component
    if not largest:
        raise RuntimeError("empty climb pose")
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    result_pixels = result.load()
    source_pixels = source.load()
    for x, y in largest:
        result_pixels[x, y] = source_pixels[x, y]
    return result


def normalized_pose(source: Image.Image) -> Image.Image:
    source = largest_connected_subject(source)
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("empty climb pose")
    cropped = source.crop(bbox)
    target_width = max(1, round(cropped.width * TARGET_HEIGHT / cropped.height))
    return hard_alpha(
        cropped.resize((target_width, TARGET_HEIGHT), Image.Resampling.NEAREST)
    )


def place_in_tile(pose: Image.Image) -> Image.Image:
    bbox = pose.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("empty normalized pose")
    tile = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    destination_x = TARGET_FORWARD_EDGE_X - bbox[2]
    destination_y = TARGET_TOP_Y - bbox[1]
    tile.alpha_composite(pose, (destination_x, destination_y))
    tile_bbox = tile.getchannel("A").getbbox()
    if tile_bbox is None or tile_bbox[2] != TARGET_FORWARD_EDGE_X:
        raise RuntimeError(f"invalid hand/contact edge: {tile_bbox}")
    if tile_bbox[0] <= 0 or tile_bbox[1] <= 0 or tile_bbox[3] >= FRAME_SIZE:
        raise RuntimeError(f"pose escaped 128x128 tile: {tile_bbox}")
    return tile


def source_tile(source: Image.Image, index: int) -> Image.Image:
    column = index % SOURCE_COLUMNS
    row = index // SOURCE_COLUMNS
    left = round(column * source.width / SOURCE_COLUMNS)
    right = round((column + 1) * source.width / SOURCE_COLUMNS)
    top = round(row * source.height / SOURCE_ROWS)
    bottom = round((row + 1) * source.height / SOURCE_ROWS)
    return source.crop((left, top, right, bottom))


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    frames = [
        place_in_tile(normalized_pose(source_tile(source, index)))
        for index in range(FRAME_COUNT)
    ]

    atlas = Image.open(ATLAS_SOURCE).convert("RGBA")
    if atlas.size != (1024, 768):
        raise RuntimeError(f"unexpected atlas size: {atlas.size}")
    hang_row = (0, 256, 1024, 384)
    atlas.paste((0, 0, 0, 0), hang_row)
    for index, frame in enumerate(frames):
        atlas.alpha_composite(frame, (index * FRAME_SIZE, 256))
    atlas.save(ATLAS_OUTPUT)

    preview = Image.new(
        "RGBA",
        (FRAME_SIZE * FRAME_COUNT * PREVIEW_SCALE, FRAME_SIZE * PREVIEW_SCALE),
        (28, 32, 40, 255),
    )
    for index, frame in enumerate(frames):
        enlarged = frame.resize(
            (FRAME_SIZE * PREVIEW_SCALE, FRAME_SIZE * PREVIEW_SCALE),
            Image.Resampling.NEAREST,
        )
        preview.alpha_composite(enlarged, (index * FRAME_SIZE * PREVIEW_SCALE, 0))
    PREVIEW_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW_OUTPUT)
    print(ATLAS_OUTPUT)
    print(PREVIEW_OUTPUT)


if __name__ == "__main__":
    main()
