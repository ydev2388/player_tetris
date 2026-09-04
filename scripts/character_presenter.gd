class_name MainCharacterPresenter
extends RefCounted

var sprite: Sprite2D
var animation_state: String = "idle"
var animation_time: float = 0.0


func setup(target_sprite: Sprite2D) -> void:
	sprite = target_sprite
	sprite.region_filter_clip_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func apply_atlas_frame(texture: Texture2D, region: Rect2) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region


func apply_geometry(scale: Vector2, local_position: Vector2) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.scale = scale
	sprite.position = local_position


func set_facing_left(left: bool) -> void:
	if is_instance_valid(sprite):
		sprite.flip_h = left


func set_rotation(value: float) -> void:
	if is_instance_valid(sprite):
		sprite.rotation = value


func set_modulate(value: Color) -> void:
	if is_instance_valid(sprite):
		sprite.modulate = value


func set_visible(value: bool) -> void:
	if is_instance_valid(sprite):
		sprite.visible = value


func reset_visual() -> void:
	animation_state = "idle"
	animation_time = 0.0
	if not is_instance_valid(sprite):
		return
	sprite.flip_h = false
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	sprite.visible = true
