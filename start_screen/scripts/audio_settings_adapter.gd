class_name BlockFighterAudioSettingsAdapter
extends RefCounted

const MUSIC_BUS: StringName = &"BGM"
const SFX_BUS: StringName = &"SFX"

var master_percent: float = 100.0
var music_percent: float = 100.0
var sfx_percent: float = 100.0


func reset_defaults() -> void:
	master_percent = 100.0
	music_percent = 100.0
	sfx_percent = 100.0


func snapshot() -> Dictionary:
	return {
		"master_percent": master_percent,
		"music_percent": music_percent,
		"sfx_percent": sfx_percent,
	}


func restore(snapshot_value: Dictionary, apply_now: bool = true) -> void:
	master_percent = clampf(float(snapshot_value.get("master_percent", 100.0)), 0.0, 100.0)
	music_percent = clampf(float(snapshot_value.get("music_percent", 100.0)), 0.0, 100.0)
	sfx_percent = clampf(float(snapshot_value.get("sfx_percent", 100.0)), 0.0, 100.0)
	if apply_now:
		apply()


func set_master_percent(value: float) -> float:
	master_percent = clampf(value, 0.0, 100.0)
	apply()
	return master_percent


func set_music_percent(value: float) -> float:
	music_percent = clampf(value, 0.0, 100.0)
	apply()
	return music_percent


func set_sfx_percent(value: float) -> float:
	sfx_percent = clampf(value, 0.0, 100.0)
	apply()
	return sfx_percent


func apply() -> void:
	ensure_buses()
	_apply_bus_volume(MUSIC_BUS, music_percent * master_percent / 100.0)
	_apply_bus_volume(SFX_BUS, sfx_percent * master_percent / 100.0)


func ensure_buses() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var effective_percent := percent * (0.5 if bus_name == SFX_BUS else 1.0)
	var muted := effective_percent <= 0.0
	AudioServer.set_bus_mute(bus_index, muted)
	AudioServer.set_bus_volume_db(
		bus_index,
		-80.0 if muted else linear_to_db(effective_percent / 100.0) - 10.0
	)
