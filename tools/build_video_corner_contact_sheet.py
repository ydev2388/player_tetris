"""Crop and enlarge the board's right-corner character area from review frames."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "build" / "corner_hang_video_frames"
OUTPUT = ROOT / "build" / "corner_hang_video_corner_contact_sheet.png"
PATHS = sorted(INPUT.glob("*.png"))
CROP = (820, 430, 950, 760)
SCALE = 2
COLUMNS = 5
LABEL_HEIGHT = 22


def main() -> None:
    if not PATHS:
        raise RuntimeError("no video frames")
    crop_width = (CROP[2] - CROP[0]) * SCALE
    crop_height = (CROP[3] - CROP[1]) * SCALE
    rows = (len(PATHS) + COLUMNS - 1) // COLUMNS
    sheet = Image.new(
        "RGB",
        (crop_width * COLUMNS, (crop_height + LABEL_HEIGHT) * rows),
        (24, 27, 32),
    )
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(PATHS):
        crop = Image.open(path).convert("RGB").crop(CROP).resize(
            (crop_width, crop_height), Image.Resampling.NEAREST
        )
        x = (index % COLUMNS) * crop_width
        y = (index // COLUMNS) * (crop_height + LABEL_HEIGHT)
        sheet.paste(crop, (x, y))
        draw.text((x + 4, y + crop_height + 3), path.stem, fill=(240, 240, 240))
    sheet.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
