from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design" / "character_previews" / "effects" / "six_character_vfx_reference_v1_rgba.png"
OUTPUT = ROOT / "assets" / "sprites" / "effects"


def fit_crop(source: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    crop = source.crop(box)
    bounds = crop.getbbox()
    if bounds:
        crop = crop.crop(bounds)
    max_w = max(1, size[0] - 4)
    max_h = max(1, size[1] - 4)
    scale = min(max_w / crop.width, max_h / crop.height)
    resized = crop.resize(
        (max(1, round(crop.width * scale)), max(1, round(crop.height * scale))),
        Image.Resampling.NEAREST,
    )
    frame = Image.new("RGBA", size)
    frame.alpha_composite(resized, ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2))
    return frame


def save_sheet(character_id: str, filename: str, frames: list[Image.Image]) -> None:
    target_dir = OUTPUT / character_id
    target_dir.mkdir(parents=True, exist_ok=True)
    frame_w, frame_h = frames[0].size
    sheet = Image.new("RGBA", (frame_w * len(frames), frame_h))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * frame_w, 0))
    sheet.save(target_dir / filename)


def alpha_scaled(image: Image.Image, factor: float) -> Image.Image:
    result = image.copy()
    alpha = result.getchannel("A").point(lambda value: round(value * factor))
    result.putalpha(alpha)
    return result


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")

    sprint_boxes = [
        (25, 45, 155, 165), (145, 35, 355, 180), (345, 25, 550, 190), (545, 25, 765, 190),
        (750, 40, 900, 185), (885, 20, 1040, 185), (1020, 25, 1200, 190), (1170, 55, 1380, 185),
    ]
    save_sheet("normal", "sprint_vfx.png", [fit_crop(source, box, (128, 128)) for box in sprint_boxes])

    impact_boxes = [
        (35, 205, 145, 350), (145, 195, 300, 365), (300, 185, 500, 370), (500, 185, 760, 375),
    ]
    save_sheet("boxer", "guard_break_impact.png", [fit_crop(source, box, (64, 64)) for box in impact_boxes])

    shield_source = fit_crop(source, (150, 380, 365, 590), (46, 46))
    barrier_frames: list[Image.Image] = []
    for frame_index, opacity in enumerate((0.35, 0.65, 0.78, 0.92, 0.55, 0.22)):
        frame = Image.new("RGBA", (48, 144))
        emblem = alpha_scaled(shield_source, opacity)
        pulse = 0 if frame_index % 2 == 0 else 1
        for row in range(3):
            frame.alpha_composite(emblem, (1 + pulse, row * 48 + 1))
        barrier_frames.append(frame)
    save_sheet("shield_guard", "shield_barrier.png", barrier_frames)

    hose_boxes = [
        (20, 590, 145, 730), (135, 590, 305, 735), (290, 575, 630, 745), (900, 575, 1385, 740),
    ]
    save_sheet("firefighter", "hose_overlay.png", [fit_crop(source, box, (192, 64)) for box in hose_boxes])
    water_boxes = [
        (25, 600, 145, 725), (135, 590, 310, 735), (300, 580, 625, 745),
        (640, 590, 735, 735), (720, 595, 815, 735), (800, 600, 900, 735),
    ]
    save_sheet("firefighter", "water_stream.png", [fit_crop(source, box, (96, 48)) for box in water_boxes])
    current = fit_crop(source, (900, 575, 1385, 745), (48, 48))
    water_path_frames = [ImageEnhance.Brightness(current).enhance(value) for value in (0.82, 1.0, 1.16, 0.94)]
    save_sheet("firefighter", "water_path.png", water_path_frames)

    cleanup_boxes = [
        (20, 735, 240, 900), (210, 730, 490, 905), (455, 725, 770, 905),
        (790, 735, 1010, 895), (930, 735, 1210, 900), (1120, 745, 1385, 900),
    ]
    save_sheet("cleaner", "cleanup_dust.png", [fit_crop(source, box, (144, 48)) for box in cleanup_boxes])

    up_boxes = [
        (15, 885, 165, 1105), (125, 865, 305, 1105), (275, 855, 485, 1110), (445, 850, 655, 1110),
    ]
    down_boxes = [
        (660, 865, 835, 1110), (800, 855, 985, 1110), (950, 855, 1140, 1110), (800, 855, 1140, 1110),
    ]
    save_sheet("chef", "pan_toss_up.png", [fit_crop(source, box, (96, 96)) for box in up_boxes])
    save_sheet("chef", "pan_toss_down.png", [fit_crop(source, box, (96, 96)) for box in down_boxes])
    failure = fit_crop(source, (1190, 870, 1395, 1110), (48, 48))
    save_sheet("chef", "pan_toss_failure.png", [alpha_scaled(failure, value) for value in (1.0, 0.65, 0.28)])


if __name__ == "__main__":
    main()
