"""Remove grounded crouch/stand poses from every character's airborne row.

The civilian receives a newly authored eight-pose jump/fall sequence.  Its
source poses share one scale factor so a bent leg never enlarges the head or
torso.  Existing skins keep their authored appearance and replace only the
two invalid late-air frames with their own stable falling silhouette.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
NORMAL_SOURCE = (
    ROOT
    / "design"
    / "character_reference"
    / "jump_fall"
    / "normal_jump_fall_airborne_8_source_v6_rgba.png"
)
NORMAL_ATLAS_SOURCE = (
    ROOT
    / "assets"
    / "sprites"
    / "characters"
    / "normal"
    / "normal_reference_atlas_v7.png"
)
NORMAL_ATLAS_OUTPUT = NORMAL_ATLAS_SOURCE.with_name("normal_reference_atlas_v8.png")
PREVIEW_OUTPUT = ROOT / "build" / "normal_jump_fall_v8_8_frames.png"

OTHER_CHARACTERS = (
    "boxer",
    "shield_guard",
    "firefighter",
    "cleaner",
    "chef",
    "clockmaker",
    "ninja",
)

FRAME_SIZE = 128
SOURCE_COLUMNS = 4
SOURCE_ROWS = 2
FRAME_COUNT = 8
JUMP_ROW_Y = 384
TARGET_MAX_HEIGHT = 96
TARGET_TOP_Y = 12
TARGET_CENTER_X = 64
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
        raise RuntimeError("empty airborne pose")
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    result_pixels = result.load()
    source_pixels = source.load()
    for x, y in largest:
        result_pixels[x, y] = source_pixels[x, y]
    return result


def source_tile(source: Image.Image, index: int) -> Image.Image:
    column = index % SOURCE_COLUMNS
    row = index // SOURCE_COLUMNS
    left = round(column * source.width / SOURCE_COLUMNS)
    right = round((column + 1) * source.width / SOURCE_COLUMNS)
    top = round(row * source.height / SOURCE_ROWS)
    bottom = round((row + 1) * source.height / SOURCE_ROWS)
    return source.crop((left, top, right, bottom))


def build_normal_frames(source: Image.Image) -> list[Image.Image]:
    subjects: list[Image.Image] = []
    bboxes: list[tuple[int, int, int, int]] = []
    for index in range(FRAME_COUNT):
        subject = largest_connected_subject(source_tile(source, index))
        bbox = subject.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError(f"normal jump frame {index} is empty")
        subjects.append(subject.crop(bbox))
        bboxes.append(bbox)

    # One shared scale preserves absolute head/torso/limb size across all poses.
    common_scale = TARGET_MAX_HEIGHT / float(max(subject.height for subject in subjects))
    frames: list[Image.Image] = []
    for index, subject in enumerate(subjects):
        width = max(1, round(subject.width * common_scale))
        height = max(1, round(subject.height * common_scale))
        pose = hard_alpha(subject.resize((width, height), Image.Resampling.NEAREST))
        tile = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        destination_x = TARGET_CENTER_X - width // 2
        tile.alpha_composite(pose, (destination_x, TARGET_TOP_Y))
        tile_bbox = tile.getchannel("A").getbbox()
        if tile_bbox is None:
            raise RuntimeError(f"normal jump frame {index} became empty")
        if tile_bbox[0] <= 0 or tile_bbox[1] <= 0 or tile_bbox[2] >= 128 or tile_bbox[3] >= 128:
            raise RuntimeError(f"normal jump frame {index} escaped tile: {tile_bbox}")
        frames.append(tile)
    return frames


def replace_jump_row(atlas: Image.Image, frames: list[Image.Image]) -> None:
    atlas.paste((0, 0, 0, 0), (0, JUMP_ROW_Y, 1024, JUMP_ROW_Y + FRAME_SIZE))
    for index, frame in enumerate(frames):
        atlas.alpha_composite(frame, (index * FRAME_SIZE, JUMP_ROW_Y))


def build_normal() -> None:
    source = Image.open(NORMAL_SOURCE).convert("RGBA")
    frames = build_normal_frames(source)
    atlas = Image.open(NORMAL_ATLAS_SOURCE).convert("RGBA")
    if atlas.size != (1024, 768):
        raise RuntimeError(f"unexpected normal atlas size: {atlas.size}")
    replace_jump_row(atlas, frames)
    atlas.save(NORMAL_ATLAS_OUTPUT)

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


def build_existing_skin(character_id: str) -> Path:
    directory = ROOT / "assets" / "sprites" / "characters" / character_id
    source_path = directory / f"{character_id}_reference_atlas_v5.png"
    output_path = directory / f"{character_id}_reference_atlas_v6.png"
    atlas = Image.open(source_path).convert("RGBA")
    if atlas.size != (1024, 768):
        raise RuntimeError(f"unexpected {character_id} atlas size: {atlas.size}")

    # Frame 5 is the skin's authored, extended falling pose.  Reuse it for the
    # two late-air slots that formerly contained a squat and a grounded stand.
    stable_fall = atlas.crop((5 * FRAME_SIZE, JUMP_ROW_Y, 6 * FRAME_SIZE, JUMP_ROW_Y + FRAME_SIZE))
    if stable_fall.getchannel("A").getbbox() is None:
        raise RuntimeError(f"{character_id} stable fall frame is empty")
    for index in (6, 7):
        box = (index * FRAME_SIZE, JUMP_ROW_Y, (index + 1) * FRAME_SIZE, JUMP_ROW_Y + FRAME_SIZE)
        atlas.paste((0, 0, 0, 0), box)
        atlas.alpha_composite(stable_fall, (index * FRAME_SIZE, JUMP_ROW_Y))
    atlas.save(output_path)
    return output_path


def main() -> None:
    build_normal()
    print(NORMAL_ATLAS_OUTPUT)
    print(PREVIEW_OUTPUT)
    for character_id in OTHER_CHARACTERS:
        print(build_existing_skin(character_id))


if __name__ == "__main__":
    main()
