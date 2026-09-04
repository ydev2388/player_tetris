class_name MainCharacterAudioAdapter
extends RefCounted

var _owner: Node
var _primary: AudioStreamPlayer
var _cue: AudioStreamPlayer
var _meditation: AudioStreamPlayer
var _special: AudioStreamPlayer
var _special_streams: Dictionary = {}
var _meditation_loop_enabled: bool = false


func setup(owner: Node, special_streams: Dictionary) -> void:
	_owner = owner
	_special_streams = special_streams
	_primary = _create_player(&"PrimarySfx")
	_cue = _create_player(&"CueSfx")
	_meditation = _create_player(&"MeditationSfx")
	_special = _create_player(&"SpecialSfx")
	_meditation.finished.connect(restart_meditation)


func play_primary(stream: AudioStream) -> void:
	_play(_primary, stream)


func play_cue(stream: AudioStream) -> void:
	_play(_cue, stream)


func play_special(character_id: String) -> void:
	_play(_special, _special_streams.get(character_id) as AudioStream)


func start_meditation(stream: AudioStream) -> void:
	if not is_instance_valid(_meditation):
		return
	_meditation_loop_enabled = true
	_meditation.stop()
	_meditation.stream = stream
	_meditation.play()


func stop_meditation() -> void:
	_meditation_loop_enabled = false
	if is_instance_valid(_meditation):
		_meditation.stop()


func restart_meditation() -> void:
	if (
		_meditation_loop_enabled
		and is_instance_valid(_meditation)
		and _meditation.stream != null
	):
		_meditation.play()


func stop_special() -> void:
	if is_instance_valid(_special):
		_special.stop()


func stop_all(clear_streams: bool = false) -> void:
	_meditation_loop_enabled = false
	for player: AudioStreamPlayer in [_primary, _cue, _meditation, _special]:
		if not is_instance_valid(player):
			continue
		player.stop()
		if clear_streams:
			player.stream = null


func is_meditation_playing() -> bool:
	return is_instance_valid(_meditation) and _meditation.playing


func primary_stream() -> AudioStream:
	return _primary.stream if is_instance_valid(_primary) else null


func cue_stream() -> AudioStream:
	return _cue.stream if is_instance_valid(_cue) else null


func meditation_stream() -> AudioStream:
	return _meditation.stream if is_instance_valid(_meditation) else null


func special_stream() -> AudioStream:
	return _special.stream if is_instance_valid(_special) else null


func special_player_name() -> StringName:
	return _special.name if is_instance_valid(_special) else &""


func _create_player(player_name: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"SFX"
	_owner.add_child(player)
	return player


func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if not is_instance_valid(player) or stream == null:
		return
	player.stop()
	player.stream = stream
	player.play()
