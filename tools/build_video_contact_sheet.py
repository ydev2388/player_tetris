"""Build a compact contact sheet from extracted video-review PNG frames."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--columns", type=int, default=5)
    args = parser.parse_args()

    paths = sorted(Path(args.input).glob("*.png"))
    if not paths:
        raise RuntimeError("no extracted frames")
    first = Image.open(paths[0]).convert("RGB")
    target_width = 376
    target_height = round(first.height * target_width / first.width)
    label_height = 24
    columns = args.columns
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new(
        "RGB",
        (target_width * columns, (target_height + label_height) * rows),
        (24, 27, 32),
    )
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(paths):
        frame = Image.open(path).convert("RGB").resize(
            (target_width, target_height), Image.Resampling.LANCZOS
        )
        x = (index % columns) * target_width
        y = (index // columns) * (target_height + label_height)
        sheet.paste(frame, (x, y))
        draw.text((x + 6, y + target_height + 4), path.stem, fill=(240, 240, 240))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    print(output)


if __name__ == "__main__":
    main()
