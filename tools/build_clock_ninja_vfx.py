from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "design" / "character_vfx_sources"
OUTPUT_DIR = ROOT / "assets" / "sprites" / "effects"


def fit_frame(source: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    crop = source.crop(box)
    bounds = crop.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"Empty VFX slot: {box}")
    crop = crop.crop(bounds)
    scale = min((size[0] - 6) / crop.width, (size[1] - 6) / crop.height)
    resized = crop.resize(
        (max(1, round(crop.width * scale)), max(1, round(crop.height * scale))),
        Image.Resampling.NEAREST,
    )
    alpha = resized.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    resized.putalpha(alpha)
    frame = Image.new("RGBA", size, (0, 0, 0, 0))
    frame.alpha_composite(resized, ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2))
    return frame


def row_frames(
    source: Image.Image,
    top: int,
    bottom: int,
    count: int,
    size: tuple[int, int],
) -> list[Image.Image]:
    slot_width = source.width / count
    return [
        fit_frame(
            source,
            (round(index * slot_width), top, round((index + 1) * slot_width), bottom),
            size,
        )
        for index in range(count)
    ]


def save_sheet(path: Path, rows: list[list[Image.Image]]) -> None:
    frame_width, frame_height = rows[0][0].size
    if any(frame.size != (frame_width, frame_height) for row in rows for frame in row):
        raise ValueError(f"Mixed frame sizes for {path}")
    width = frame_width * max(len(row) for row in rows)
    sheet = Image.new("RGBA", (width, frame_height * len(rows)), (0, 0, 0, 0))
    for row_index, row in enumerate(rows):
        for column, frame in enumerate(row):
            sheet.alpha_composite(frame, (column * frame_width, row_index * frame_height))
    validate_sheet(sheet, rows, frame_width, frame_height)
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def validate_sheet(
    sheet: Image.Image,
    rows: list[list[Image.Image]],
    frame_width: int,
    frame_height: int,
) -> None:
    if not set(sheet.getchannel("A").get_flattened_data()).issubset({0, 255}):
        raise ValueError("VFX sheet contains partial alpha")
    for row_index, row in enumerate(rows):
        for column in range(max(len(candidate) for candidate in rows)):
            frame = sheet.crop(
                (
                    column * frame_width,
                    row_index * frame_height,
                    (column + 1) * frame_width,
                    (row_index + 1) * frame_height,
                )
            )
            occupied = frame.getchannel("A").getbbox() is not None
            if occupied != (column < len(row)):
                raise ValueError(f"Unexpected occupancy row={row_index} column={column}")
            if not occupied:
                continue
            alpha = frame.getchannel("A")
            border = (
                list(alpha.crop((0, 0, frame_width, 1)).get_flattened_data())
                + list(alpha.crop((0, frame_height - 1, frame_width, frame_height)).get_flattened_data())
                + list(alpha.crop((0, 0, 1, frame_height)).get_flattened_data())
                + list(alpha.crop((frame_width - 1, 0, frame_width, frame_height)).get_flattened_data())
            )
            if any(border):
                raise ValueError(f"VFX touches frame boundary row={row_index} column={column}")


def main() -> None:
    clock = Image.open(SOURCE_DIR / "clockmaker_vfx_alpha_v1.png").convert("RGBA")
    ninja = Image.open(SOURCE_DIR / "ninja_vfx_alpha_v1.png").convert("RGBA")

    clock_wave = row_frames(clock, 100, 510, 6, (192, 192))
    clock_gear = row_frames(clock, 510, 1000, 4, (128, 128))
    ninja_spin = row_frames(ninja, 20, 330, 4, (32, 32))
    ninja_success = row_frames(ninja, 330, 690, 4, (64, 64))
    ninja_failure = row_frames(ninja, 690, 1024, 4, (64, 64))

    save_sheet(OUTPUT_DIR / "clockmaker" / "clock_wave.png", [clock_wave])
    save_sheet(OUTPUT_DIR / "clockmaker" / "clock_gear_ring.png", [clock_gear])
    save_sheet(OUTPUT_DIR / "ninja" / "shuriken_spin.png", [ninja_spin])
    save_sheet(OUTPUT_DIR / "ninja" / "shuriken_impact.png", [ninja_success, ninja_failure])


if __name__ == "__main__":
    main()
