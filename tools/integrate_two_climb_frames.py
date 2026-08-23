"""Replace two climb cells with generated poses while preserving the atlas.

The generated study is a 2x1 image on a magenta background.  Only climb
frames 1 and 2 (the bottom atlas row) are replaced; every other byte-sized
cell is copied from the approved character atlas.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from build_character_corner_climb_atlas import (
    _hard_alpha,
    _opaque_bbox,
    _remove_boundary_checker,
    _remove_far_specks,
)


FRAME_SIZE = 128
CLIMB_ROW_Y = 768
CONTACT_BASELINE_Y = 112


def _clean_half(generated: Image.Image, index: int) -> Image.Image:
    left = round(index * generated.width / 2)
    right = round((index + 1) * generated.width / 2)
    half = generated.crop((left, 0, right, generated.height))
    half = _remove_boundary_checker(half)
    half = _hard_alpha(half)
    half = _remove_far_specks(half)
    return half.crop(_opaque_bbox(half))


def _fit_pose(
    pose: Image.Image,
    target_height: int,
    target_center_x: float,
) -> Image.Image:
    scale = target_height / pose.height
    target_width = max(1, round(pose.width * scale))
    resized = pose.resize(
        (target_width, target_height),
        Image.Resampling.NEAREST,
    )
    resized = _hard_alpha(resized)
    target_x = round(target_center_x - target_width * 0.5)
    target_y = CONTACT_BASELINE_Y - target_height
    if (
        target_x < 0
        or target_y < 0
        or target_x + target_width > FRAME_SIZE
        or target_y + target_height > FRAME_SIZE
    ):
        raise AssertionError(
            f"pose exceeds cell: position=({target_x}, {target_y}), "
            f"size={resized.size}"
        )
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    frame.alpha_composite(resized, (target_x, target_y))
    return frame


def _parse_heights(value: str) -> tuple[int, int]:
    heights = tuple(int(part) for part in value.split(","))
    if len(heights) != 2 or any(not 64 <= height <= 112 for height in heights):
        raise argparse.ArgumentTypeError("heights must be two values in 64..112")
    return heights  # type: ignore[return-value]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--generated", type=Path, required=True)
    parser.add_argument("--atlas", type=Path, required=True)
    parser.add_argument("--pose-reference", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--target-heights", type=_parse_heights, default=(100, 95))
    args = parser.parse_args()

    generated = Image.open(args.generated).convert("RGBA")
    atlas = Image.open(args.atlas).convert("RGBA")
    pose_reference = Image.open(args.pose_reference).convert("RGBA")
    if atlas.size != (1024, 896) or pose_reference.size != (1024, 896):
        raise AssertionError("atlas and pose reference must both be 1024x896")

    output = atlas.copy()
    for index, target_height in enumerate(args.target_heights):
        pose_bbox = _opaque_bbox(
            pose_reference.crop(
                (
                    index * FRAME_SIZE,
                    CLIMB_ROW_Y,
                    (index + 1) * FRAME_SIZE,
                    CLIMB_ROW_Y + FRAME_SIZE,
                )
            )
        )
        pose_center_x = (pose_bbox[0] + pose_bbox[2]) * 0.5
        frame = _fit_pose(_clean_half(generated, index), target_height, pose_center_x)
        output.paste(frame, (index * FRAME_SIZE, CLIMB_ROW_Y))

    # Prove that only the requested two cells changed.
    if output.crop((0, 0, 1024, CLIMB_ROW_Y)).tobytes() != atlas.crop(
        (0, 0, 1024, CLIMB_ROW_Y)
    ).tobytes():
        raise AssertionError("existing animation rows changed")
    if output.crop((256, CLIMB_ROW_Y, 1024, 896)).tobytes() != atlas.crop(
        (256, CLIMB_ROW_Y, 1024, 896)
    ).tobytes():
        raise AssertionError("unrequested climb frames changed")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output, optimize=False)
    if args.preview:
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        output.crop((0, CLIMB_ROW_Y, 1024, 896)).save(args.preview, optimize=False)


if __name__ == "__main__":
    main()
