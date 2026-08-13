"""Build skill-specific special rows without changing the shared visual rig.

The generated sources use a green chroma background and eight equally spaced
poses.  Chroma removal is border-connected so green details inside a costume
are not erased.  Every pose in a strip receives one global scale derived from
its first standing pose; individual frames are never fitted independently.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DESIGN_ROOT = ROOT / "design" / "character_skins_v2"
ASSET_ROOT = ROOT / "assets" / "sprites" / "characters"
CHARACTER_IDS = (
    "boxer",
    "shield_guard",
    "firefighter",
    "cleaner",
    "chef",
    "clockmaker",
    "ninja",
)
FRAME_COUNT = 8
TILE_SIZE = 128
SPECIAL_ROW_Y = 5 * TILE_SIZE
SOLE_BASELINE_Y = 109


def is_chroma(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = pixel
    return green >= 105 and green >= red * 1.45 and green >= blue * 1.35


def remove_border_chroma(source: Image.Image) -> Image.Image:
    """Remove only green pixels connected to the canvas border."""

    rgba = source.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not is_chroma(pixels[x, y]):
            continue
        seen.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))

    # Generated pixel art has a narrow green matte.  Clear strongly green
    # remaining edge pixels and harden alpha for nearest-neighbour rendering.
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            if green >= 150 and green >= red * 1.75 and green >= blue * 1.55:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)
    return rgba


def keep_primary_figure_per_frame(source: Image.Image) -> Image.Image:
    """Drop detached generated VFX; runtime gameplay draws those separately."""

    output = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for column in range(FRAME_COUNT):
        left = round(column * source.width / FRAME_COUNT)
        right = round((column + 1) * source.width / FRAME_COUNT)
        cell = source.crop((left, 0, right, source.height))
        alpha = cell.getchannel("A")
        width, height = cell.size
        visited: set[tuple[int, int]] = set()
        components: list[list[tuple[int, int]]] = []
        for y in range(height):
            for x in range(width):
                if (x, y) in visited or alpha.getpixel((x, y)) == 0:
                    continue
                component: list[tuple[int, int]] = []
                queue: deque[tuple[int, int]] = deque([(x, y)])
                visited.add((x, y))
                while queue:
                    px, py = queue.popleft()
                    component.append((px, py))
                    for offset_x, offset_y in (
                        (-1, -1), (0, -1), (1, -1),
                        (-1, 0),            (1, 0),
                        (-1, 1),  (0, 1),   (1, 1),
                    ):
                        nx, ny = px + offset_x, py + offset_y
                        if not (0 <= nx < width and 0 <= ny < height):
                            continue
                        if (nx, ny) in visited or alpha.getpixel((nx, ny)) == 0:
                            continue
                        visited.add((nx, ny))
                        queue.append((nx, ny))
                components.append(component)
        if not components:
            raise RuntimeError(f"special source frame {column + 1} has no primary figure")
        primary = max(components, key=len)
        primary_set = set(primary)
        cleaned = Image.new("RGBA", cell.size, (0, 0, 0, 0))
        cleaned_pixels = cleaned.load()
        cell_pixels = cell.load()
        for x, y in primary_set:
            cleaned_pixels[x, y] = cell_pixels[x, y]
        output.alpha_composite(cleaned, (left, 0))
    return output


def frame_box(source: Image.Image, column: int) -> tuple[int, int, int, int]:
    left = round(column * source.width / FRAME_COUNT)
    right = round((column + 1) * source.width / FRAME_COUNT)
    bbox = source.crop((left, 0, right, source.height)).getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"empty special source frame {column + 1}")
    return left, right, bbox[0], bbox[1], bbox[2], bbox[3]


def idle_height(character_id: str) -> int:
    path = ASSET_ROOT / character_id / f"{character_id}_reference_atlas_v2.png"
    atlas = Image.open(path).convert("RGBA")
    bbox = atlas.crop((0, 0, TILE_SIZE, TILE_SIZE)).getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"{character_id}: v2 idle frame is empty")
    return bbox[3] - bbox[1]


def build_character(character_id: str) -> tuple[Path, Path, Path]:
    design_dir = DESIGN_ROOT / character_id
    chroma_path = design_dir / f"{character_id}_special_strip_chroma_v3.png"
    source = keep_primary_figure_per_frame(remove_border_chroma(Image.open(chroma_path)))
    rgba_path = design_dir / f"{character_id}_special_strip_rgba_v3.png"
    source.save(rgba_path)

    first = frame_box(source, 0)
    first_height = first[5] - first[3]
    global_scale = idle_height(character_id) / max(1, first_height)

    v2_path = ASSET_ROOT / character_id / f"{character_id}_reference_atlas_v2.png"
    atlas = Image.open(v2_path).convert("RGBA")
    # Clear only the special row.  The first 28 frames stay byte-for-byte visual copies.
    atlas.paste((0, 0, 0, 0), (0, SPECIAL_ROW_Y, atlas.width, SPECIAL_ROW_Y + TILE_SIZE))

    for column in range(FRAME_COUNT):
        left, right, box_left, box_top, box_right, box_bottom = frame_box(source, column)
        figure = source.crop((left + box_left, box_top, left + box_right, box_bottom))
        output_size = (
            max(1, round(figure.width * global_scale)),
            max(1, round(figure.height * global_scale)),
        )
        figure = figure.resize(output_size, Image.Resampling.NEAREST)

        source_cell_width = right - left
        paste_x = round(TILE_SIZE * 0.5 + (box_left - source_cell_width * 0.5) * global_scale)
        paste_y = SOLE_BASELINE_Y + 1 - figure.height
        tile = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
        tile.alpha_composite(figure, (paste_x, paste_y))
        bbox = tile.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError(f"{character_id}: special frame {column + 1} was clipped away")
        if bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= TILE_SIZE or bbox[3] >= TILE_SIZE:
            raise RuntimeError(f"{character_id}: special frame {column + 1} touches tile edge: {bbox}")
        atlas.alpha_composite(tile, (column * TILE_SIZE, SPECIAL_ROW_Y))

    output = ASSET_ROOT / character_id / f"{character_id}_reference_atlas_v3.png"
    atlas.save(output)
    contact = design_dir / f"{character_id}_contact_sheet_v3.png"
    atlas.resize((4096, 3072), Image.Resampling.NEAREST).save(contact)
    return output, rgba_path, contact


def main() -> None:
    for character_id in CHARACTER_IDS:
        output, rgba, contact = build_character(character_id)
        print(output)
        print(rgba)
        print(contact)


if __name__ == "__main__":
    main()
