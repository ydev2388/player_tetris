"""Static contract checks for the normal-character reference atlas."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ATLAS = (
    ROOT
    / "assets"
    / "sprites"
    / "characters"
    / "normal"
    / "normal_reference_atlas_v2.png"
)
FRAME_COUNTS = (4, 4, 4, 8, 8, 8)
TILE_SIZE = 128


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    atlas = Image.open(ATLAS)
    require(atlas.mode == "RGBA", f"Expected RGBA, got {atlas.mode}")
    require(atlas.size == (1024, 768), f"Expected 1024x768, got {atlas.size}")

    frame_count = 0
    for row, count in enumerate(FRAME_COUNTS):
        for column in range(count):
            tile = atlas.crop(
                (
                    column * TILE_SIZE,
                    row * TILE_SIZE,
                    (column + 1) * TILE_SIZE,
                    (row + 1) * TILE_SIZE,
                )
            )
            bbox = tile.getchannel("A").getbbox()
            require(bbox is not None, f"Empty required frame at row {row + 1}, column {column + 1}")
            require(
                bbox[0] > 0 and bbox[1] > 0 and bbox[2] < TILE_SIZE and bbox[3] < TILE_SIZE,
                f"Frame touches its 128x128 boundary at row {row + 1}, column {column + 1}: {bbox}",
            )
            frame_count += 1

    require(frame_count == 36, f"Expected 36 required frames, got {frame_count}")

    # Grounded construction poses share pixel row 109 as their sole baseline.
    grounded_frames = ((0, 0), (0, 3), (1, 0), (1, 3), (3, 7), (4, 0), (4, 7), (5, 0), (5, 6), (5, 7))
    for row, column in grounded_frames:
        tile = atlas.crop(
            (
                column * TILE_SIZE,
                row * TILE_SIZE,
                (column + 1) * TILE_SIZE,
                (row + 1) * TILE_SIZE,
            )
        )
        bbox = tile.getchannel("A").getbbox()
        require(bbox is not None and bbox[3] in (109, 110, 111), f"Ground anchor drift: {(row, column)} {bbox}")

    # Standing frames stay approximately 90 pixels tall. Crouches/tucks are
    # deliberately excluded because their shorter silhouette must not be scaled.
    standing_frames = ((0, 0), (0, 1), (0, 3), (1, 0), (1, 3), (3, 7), (4, 0), (4, 7), (5, 0), (5, 6), (5, 7))
    for row, column in standing_frames:
        tile = atlas.crop(
            (
                column * TILE_SIZE,
                row * TILE_SIZE,
                (column + 1) * TILE_SIZE,
                (row + 1) * TILE_SIZE,
            )
        )
        bbox = tile.getchannel("A").getbbox()
        require(bbox is not None and 88 <= bbox[3] - bbox[1] <= 92, f"Standing height drift: {(row, column)} {bbox}")

    print("normal reference atlas: 36/36 frames valid, RGBA 1024x768, fixed anchors valid")


if __name__ == "__main__":
    main()
