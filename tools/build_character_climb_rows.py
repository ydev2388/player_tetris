"""Build an unmistakable four-frame wall-climb cycle for every character.

The existing hang art already has the correct skin, scale, hand contact edge,
and four authored leg poses.  This pass preserves every pixel in those poses,
orders the most distinct poses next to each other, and adds a small climbing
rise/fall beat.  No limb is cut apart, warped, or rescaled.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
FRAME_SIZE = 128
HANG_TOP = 256
ALPHA_THRESHOLD = 128
TARGET_FORWARD_EDGE_X = 87

SOURCES = {
    "normal": "normal_reference_atlas_v3.png",
    "boxer": "boxer_reference_atlas_v4.png",
    "shield_guard": "shield_guard_reference_atlas_v4.png",
    "firefighter": "firefighter_reference_atlas_v4.png",
    "cleaner": "cleaner_reference_atlas_v4.png",
    "chef": "chef_reference_atlas_v4.png",
    "clockmaker": "clockmaker_reference_atlas_v4.png",
    "ninja": "ninja_reference_atlas_v4.png",
}

OUTPUTS = {
    "normal": "normal_reference_atlas_v4.png",
    "boxer": "boxer_reference_atlas_v5.png",
    "shield_guard": "shield_guard_reference_atlas_v5.png",
    "firefighter": "firefighter_reference_atlas_v5.png",
    "cleaner": "cleaner_reference_atlas_v5.png",
    "chef": "chef_reference_atlas_v5.png",
    "clockmaker": "clockmaker_reference_atlas_v5.png",
    "ninja": "ninja_reference_atlas_v5.png",
}


def solid_bbox(frame: Image.Image):
    return frame.getchannel("A").point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    ).getbbox()


def translated_y(source: Image.Image, offset_y: int) -> Image.Image:
    bbox = solid_bbox(source)
    if bbox is None:
        raise RuntimeError("cannot translate an empty climb pose")
    offset_y = max(1 - bbox[1], min(offset_y, 127 - bbox[3]))
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    result.alpha_composite(source, (0, offset_y))
    return result


def build(character_id: str) -> None:
    directory = ROOT / "assets" / "sprites" / "characters" / character_id
    source_path = directory / SOURCES[character_id]
    output_path = directory / OUTPUTS[character_id]
    atlas = Image.open(source_path).convert("RGBA")
    if atlas.size != (1024, 768):
        raise RuntimeError(f"unexpected {character_id} atlas size: {atlas.size}")

    source_frames = [
        atlas.crop((column * FRAME_SIZE, HANG_TOP, (column + 1) * FRAME_SIZE, HANG_TOP + FRAME_SIZE))
        for column in range(4)
    ]
    # Contact -> pull -> high contact -> recovery.  Frame four is generally
    # the largest authored leg change in the source atlases, so it is placed
    # immediately after frame one instead of being hidden at the cycle end.
    pose_order = (0, 3, 2, 1)
    climb_offsets_y = (2, 0, -2, 0)
    frames = [
        translated_y(source_frames[source_index], offset_y)
        for source_index, offset_y in zip(pose_order, climb_offsets_y)
    ]
    for column, frame in enumerate(frames):
        bbox = solid_bbox(frame)
        if bbox is None:
            raise RuntimeError(f"{character_id}: empty generated hang frame {column}")
        if bbox[2] != TARGET_FORWARD_EDGE_X:
            raise RuntimeError(
                f"{character_id}: hand contact moved in frame {column}: {bbox}"
            )
        tile_box = (
            column * FRAME_SIZE,
            HANG_TOP,
            (column + 1) * FRAME_SIZE,
            HANG_TOP + FRAME_SIZE,
        )
        atlas.paste((0, 0, 0, 0), tile_box)
        atlas.alpha_composite(frame, (column * FRAME_SIZE, HANG_TOP))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output_path)
    print(f"{character_id}: climb frames -> {output_path.name}")


def main() -> None:
    for character_id in SOURCES:
        build(character_id)


if __name__ == "__main__":
    main()
