"""Create versioned atlases whose hanging hands meet the shared collider wall.

Character art faces right and Godot mirrors it when facing left. Only the four
hang tiles are translated; their pixels, scale, baseline, and all other rows are
preserved byte-for-byte from the source atlas.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
FRAME_SIZE = 128
HANG_ROW = 2
HANG_FRAME_COUNT = 4
ALPHA_THRESHOLD = 128
FRAME_CENTER_X = 64
COLLIDER_HALF_WIDTH = 21
# Blocks are drawn inside their physical cell by about two pixels
# (destination grow(-1) plus the source border). Let the visible hand overlap
# only that decorative inset so art touches art while physics stays unchanged.
BLOCK_VISUAL_INSET = 2
TARGET_FORWARD_EDGE_X = FRAME_CENTER_X + COLLIDER_HALF_WIDTH + BLOCK_VISUAL_INSET
SOURCES = {
    "normal": "normal_reference_atlas_v2.png",
    "boxer": "boxer_reference_atlas_v3.png",
    "shield_guard": "shield_guard_reference_atlas_v3.png",
    "firefighter": "firefighter_reference_atlas_v3.png",
    "cleaner": "cleaner_reference_atlas_v3.png",
    "chef": "chef_reference_atlas_v3.png",
    "clockmaker": "clockmaker_reference_atlas_v3.png",
    "ninja": "ninja_reference_atlas_v3.png",
}
OUTPUTS = {
    "normal": "normal_reference_atlas_v3.png",
    "boxer": "boxer_reference_atlas_v4.png",
    "shield_guard": "shield_guard_reference_atlas_v4.png",
    "firefighter": "firefighter_reference_atlas_v4.png",
    "cleaner": "cleaner_reference_atlas_v4.png",
    "chef": "chef_reference_atlas_v4.png",
    "clockmaker": "clockmaker_reference_atlas_v4.png",
    "ninja": "ninja_reference_atlas_v4.png",
}


def alpha_bbox(frame: Image.Image):
    alpha = frame.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    return mask.getbbox()


def translated(frame: Image.Image, offset_x: int) -> Image.Image:
    result = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    result.alpha_composite(frame, (offset_x, 0))
    return result


def build(character_id: str) -> None:
    directory = ROOT / "assets" / "sprites" / "characters" / character_id
    source_path = directory / SOURCES[character_id]
    output_path = directory / OUTPUTS[character_id]
    atlas = Image.open(source_path).convert("RGBA")
    if atlas.size != (1024, 768):
        raise RuntimeError(f"unexpected {character_id} atlas size: {atlas.size}")

    shifts: list[int] = []
    for column in range(HANG_FRAME_COUNT):
        left = column * FRAME_SIZE
        top = HANG_ROW * FRAME_SIZE
        tile_box = (left, top, left + FRAME_SIZE, top + FRAME_SIZE)
        frame = atlas.crop(tile_box)
        bbox = alpha_bbox(frame)
        if bbox is None:
            raise RuntimeError(f"{character_id} hang frame {column} is empty")

        # bbox[2] is exclusive. The opaque outer edge passes the physical
        # collider face only by the block sprite's decorative inset.
        offset_x = TARGET_FORWARD_EDGE_X - bbox[2]
        moved = translated(frame, offset_x)
        moved_bbox = alpha_bbox(moved)
        if moved_bbox is None or moved_bbox[2] != TARGET_FORWARD_EDGE_X:
            raise RuntimeError(
                f"failed to align {character_id} hang frame {column}: {moved_bbox}"
            )
        if moved_bbox[0] <= 0 or moved_bbox[3] >= FRAME_SIZE:
            raise RuntimeError(
                f"aligned {character_id} hang frame {column} escaped tile: {moved_bbox}"
            )
        atlas.paste((0, 0, 0, 0), tile_box)
        atlas.alpha_composite(moved, (left, top))
        shifts.append(offset_x)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output_path)
    print(f"{character_id}: hang shifts {shifts} -> {output_path.name}")


def main() -> None:
    for character_id in SOURCES:
        build(character_id)


if __name__ == "__main__":
    main()
