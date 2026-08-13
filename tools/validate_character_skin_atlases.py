"""Validate the shared fixed-geometry contract for all eight character skins."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CHARACTERS = (
    "normal",
    "boxer",
    "shield_guard",
    "firefighter",
    "cleaner",
    "chef",
    "clockmaker",
    "ninja",
)
DEFAULT_COUNTS = (4, 4, 4, 8, 8, 8)
NORMAL_COUNTS = (4, 4, 8, 8, 8, 8)


def atlas_path(character_id: str) -> Path:
    filename = (
        "normal_reference_atlas_v8.png"
        if character_id == "normal"
        else f"{character_id}_reference_atlas_v6.png"
    )
    return ROOT / "assets" / "sprites" / "characters" / character_id / filename


def main() -> None:
    for character_id in CHARACTERS:
        image = Image.open(atlas_path(character_id)).convert("RGBA")
        assert image.size == (1024, 768), (character_id, image.size)
        assert image.mode == "RGBA"
        required = 0
        counts = NORMAL_COUNTS if character_id == "normal" else DEFAULT_COUNTS
        for row, count in enumerate(counts):
            for column in range(count):
                tile = image.crop(
                    (column * 128, row * 128, (column + 1) * 128, (row + 1) * 128)
                )
                bbox = tile.getchannel("A").getbbox()
                assert bbox is not None, f"{character_id}: empty frame {row + 1}:{column + 1}"
                assert bbox[0] > 0 and bbox[1] > 0 and bbox[2] < 128 and bbox[3] < 128, (
                    character_id,
                    row,
                    column,
                    bbox,
                )
                required += 1
        assert required == (40 if character_id == "normal" else 36)

        hang_frame_count = 8 if character_id == "normal" else 4
        for column in range(hang_frame_count):
            hang_bbox = image.crop(
                (column * 128, 256, (column + 1) * 128, 384)
            ).getchannel("A").point(
                lambda value: 255 if value >= 128 else 0
            ).getbbox()
            assert hang_bbox is not None and hang_bbox[2] == 87, (
                character_id,
                column,
                hang_bbox,
            )

        idle = image.crop((0, 0, 128, 128)).getchannel("A").getbbox()
        assert idle is not None and 88 <= idle[3] - idle[1] <= 92, (character_id, idle)
        assert idle[3] in (109, 110, 111), (character_id, idle)

        jump_heights = []
        for column in range(8):
            jump_bbox = image.crop(
                (column * 128, 384, (column + 1) * 128, 512)
            ).getchannel("A").getbbox()
            assert jump_bbox is not None, (character_id, column)
            jump_heights.append(jump_bbox[3] - jump_bbox[1])
        # Late airborne frames must remain extended; the old landing crouch
        # was roughly half the normal body height.
        assert min(jump_heights[4:]) >= 70, (character_id, jump_heights)

        if character_id != "normal":
            stable_fall = image.crop((5 * 128, 384, 6 * 128, 512)).tobytes()
            assert image.crop((6 * 128, 384, 7 * 128, 512)).tobytes() == stable_fall
            assert image.crop((7 * 128, 384, 8 * 128, 512)).tobytes() == stable_fall

            v2 = Image.open(
                ROOT
                / "assets"
                / "sprites"
                / "characters"
                / character_id
                / f"{character_id}_reference_atlas_v2.png"
            ).convert("RGBA")
            assert image.crop((0, 0, 1024, 256)).tobytes() == v2.crop(
                (0, 0, 1024, 256)
            ).tobytes()
            assert image.crop((0, 512, 1024, 640)).tobytes() == v2.crop(
                (0, 512, 1024, 640)
            ).tobytes()
            special_heights = []
            for column in range(8):
                bbox = image.crop(
                    (column * 128, 640, (column + 1) * 128, 768)
                ).getchannel("A").getbbox()
                assert bbox is not None
                special_heights.append(bbox[3] - bbox[1])
                assert bbox[3] in (109, 110, 111), (character_id, column, bbox)
            assert max(special_heights) <= 112, (character_id, special_heights)

        expected = 40 if character_id == "normal" else 36
        print(
            f"{character_id}: {expected}/{expected} frames, "
            "1024x768 RGBA, fixed baseline and airborne fall valid"
        )


if __name__ == "__main__":
    main()
