class_name BlockFighterScreenRouter
extends RefCounted

var current_screen: int
var _views: Dictionary = {}
var _game_host: Control


func _init(initial_screen: int) -> void:
	current_screen = initial_screen


func register_view(
	screen_id: int,
	root: Control,
	on_enter: Callable = Callable()
) -> BlockFighterScreenView:
	var view := BlockFighterScreenView.new(screen_id, root, on_enter)
	_views[screen_id] = view
	return view


func set_game_host(game_host: Control) -> void:
	_game_host = game_host


func configure_view_focus(
	screen_id: int,
	candidates: Array,
	preferred_focus_index: Callable = Callable()
) -> bool:
	var view := view_for(screen_id)
	if view == null:
		return false
	view.configure_focus(candidates, preferred_focus_index)
	return true


func route(screen_id: int, game_screen_id: int) -> bool:
	if screen_id != game_screen_id and not _views.has(screen_id):
		return false
	current_screen = screen_id
	for stored_view: BlockFighterScreenView in _views.values():
		stored_view.set_active(false)
	if is_instance_valid(_game_host):
		_game_host.visible = screen_id == game_screen_id
	if screen_id != game_screen_id:
		(_views[screen_id] as BlockFighterScreenView).enter()
	return true


func view_for(screen_id: int) -> BlockFighterScreenView:
	return _views.get(screen_id) as BlockFighterScreenView
