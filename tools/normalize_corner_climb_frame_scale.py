"""Normalize selected corner-climb frame scales without redrawing pixel art.

Only the opaque character crop in the requested 128x128 cells is resized with
nearest-neighbor sampling. Existing animation rows and unlisted climb frames
remain byte-for-byte identical. Every edited pose keeps its horizontal center
and the shared source-cell contact baseline at y=112.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


FRAME_SIZE = 128
CLIMB_ROW_Y = 768
CONTACT_BASELINE_Y = 112
ALPHA_THRESHOLD = 96


def _opaque_bbox(frame: Image.Image) -> tuple[int, int, int, int]:
    alpha = frame.getchannel("A").point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    )
    bbox = alpha.getbbox()
    if bbox is None:
        raise AssertionError("frame contains no opaque pixels")
    return bbox


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


def _normalized_frame(frame: Image.Image, scale: float) -> Image.Image:
    bbox = _opaque_bbox(frame)
    character = frame.crop(bbox)
    target_width = max(1, round(character.width * scale))
    target_height = max(1, round(character.height * scale))
    character = character.resize(
        (target_width, target_height),
        Image.Resampling.NEAREST,
    )
    character = _hard_alpha(character)

    source_center_x = (bbox[0] + bbox[2]) * 0.5
    target_x = round(source_center_x - target_width * 0.5)
    target_y = CONTACT_BASELINE_Y - target_height
    if (
        target_x < 0
        or target_y < 0
        or target_x + target_width > FRAME_SIZE
        or target_y + target_height > FRAME_SIZE
    ):
        raise AssertionError(
            f"scaled pose exceeds cell: position=({target_x}, {target_y}) "
            f"size=({target_width}, {target_height})"
        )

    result = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    result.alpha_composite(character, (target_x, target_y))
    return result


def _parse_scale(specification: str) -> tuple[int, float]:
    frame_text, scale_text = specification.split(":", 1)
    frame_number = int(frame_text)
    if not 1 <= frame_number <= 8:
        raise argparse.ArgumentTypeError("frame number must be 1..8")
    scale = float(scale_text)
    if not 0.5 <= scale <= 1.5:
        raise argparse.ArgumentTypeError("scale must be 0.5..1.5")
    return frame_number - 1, scale


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--scale",
        action="append",
        type=_parse_scale,
        required=True,
        help="1-based frame and multiplier, for example 1:1.12",
    )
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    if source.size != (1024, 896):
        raise AssertionError(f"unexpected atlas size: {source.size}")
    output = source.copy()
    for frame_index, scale in args.scale:
        left = frame_index * FRAME_SIZE
        source_frame = source.crop(
            (left, CLIMB_ROW_Y, left + FRAME_SIZE, CLIMB_ROW_Y + FRAME_SIZE)
        )
        output.alpha_composite(
            Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0)),
            (left, CLIMB_ROW_Y),
        )
        output.paste(
            _normalized_frame(source_frame, scale),
            (left, CLIMB_ROW_Y),
        )

    if output.crop((0, 0, 1024, CLIMB_ROW_Y)).tobytes() != source.crop(
        (0, 0, 1024, CLIMB_ROW_Y)
    ).tobytes():
        raise AssertionError("existing animation rows changed")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output, optimize=False)


if __name__ == "__main__":
    main()
