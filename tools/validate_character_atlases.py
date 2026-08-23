"""Validate the one-file sprite atlas contract for every playable character."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


FRAME_SIZE = 128
ALPHA_THRESHOLD = 96
CHARACTER_ATLASES = {
    "normal": ("normal_reference_atlas_v12.png", (1024, 896), (4, 4, 8, 8, 8, 8, 8)),
    "boxer": ("boxer_reference_atlas_v6.png", (1024, 768), (4, 4, 4, 8, 8, 8)),
    "shield_guard": ("shield_guard_reference_atlas_v6.png", (1024, 768), (4, 4, 4, 8, 8, 8)),
    "firefighter": ("firefighter_reference_atlas_v6.png", (1024, 768), (4, 4, 4, 8, 8, 8)),
    "cleaner": ("cleaner_reference_atlas_v6.png", (1024, 768), (4, 4, 4, 8, 8, 8)),
    "chef": ("chef_reference_atlas_v8.png", (1024, 768), (4, 4, 8, 8, 8, 8)),
    "clockmaker": ("clockmaker_reference_atlas_v6.png", (1024, 768), (4, 4, 4, 8, 8, 8)),
    "ninja": ("ninja_reference_atlas_v6.png", (1024, 768), (4, 4, 4, 8, 8, 8)),
}


def main() -> None:
    project_root = Path(__file__).resolve().parents[1]
    character_root = project_root / "assets" / "sprites" / "characters"
    actual_directories = sorted(
        path.name for path in character_root.iterdir() if path.is_dir()
    )
    expected_directories = sorted(CHARACTER_ATLASES)
    if actual_directories != expected_directories:
        raise AssertionError(
            "Character sprite directories must match playable character IDs: "
            f"expected={expected_directories}, actual={actual_directories}"
        )

    for character_id, contract in CHARACTER_ATLASES.items():
        atlas_name, atlas_size, required_frame_counts = contract
        sprite_dir = character_root / character_id
        png_names = sorted(path.name for path in sprite_dir.glob("*.png"))
        if png_names != [atlas_name]:
            raise AssertionError(
                f"{character_id} must have exactly one PNG atlas: "
                f"expected={[atlas_name]}, actual={png_names}"
            )

        atlas_path = sprite_dir / atlas_name
        atlas = Image.open(atlas_path).convert("RGBA")
        if atlas.size != atlas_size:
            raise AssertionError(
                f"Unexpected {character_id} atlas size: {atlas.size}"
            )

        for row_index, required_count in enumerate(required_frame_counts):
            for frame_index in range(required_count):
                frame = atlas.crop(
                    (
                        frame_index * FRAME_SIZE,
                        row_index * FRAME_SIZE,
                        (frame_index + 1) * FRAME_SIZE,
                        (row_index + 1) * FRAME_SIZE,
                    )
                )
                opaque_count = sum(
                    1
                    for alpha in frame.getchannel("A").tobytes()
                    if alpha >= ALPHA_THRESHOLD
                )
                if opaque_count == 0:
                    raise AssertionError(
                        f"{character_id} atlas row {row_index + 1}, "
                        f"frame {frame_index + 1} is empty"
                    )
        print(f"{character_id}={atlas_path.name}, size={atlas.size}")


if __name__ == "__main__":
    main()
