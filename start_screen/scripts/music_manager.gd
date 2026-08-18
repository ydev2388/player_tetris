class_name BlockFighterMusicManager
extends Node

## 메뉴와 전투 음악을 한 곳에서 관리하며 BGM 버스의 사용자 음량 설정을 따른다.

const MENU_MUSIC: AudioStreamWAV = preload(
	"res://assets/music/block_fighter_menu_loop.wav"
)
const BATTLE_MUSIC: AudioStreamWAV = preload(
	"res://assets/music/block_fighter_battle_loop.wav"
)
const SILENT_DB: float = -60.0
const MENU_DB: float = -3.0
const BATTLE_DB: float = -5.0
const FADE_DB_PER_SECOND: float = 80.0

var _menu_player: AudioStreamPlayer
var _battle_player: AudioStreamPlayer
var _active_mode: StringName = &""
var _menu_target_db: float = SILENT_DB
var _battle_target_db: float = SILENT_DB


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_player = _create_player(_looped_copy(MENU_MUSIC), "MenuMusic")
	_battle_player = _create_player(_looped_copy(BATTLE_MUSIC), "BattleMusic")
	play_menu(true)


func _process(delta: float) -> void:
	_menu_player.volume_db = move_toward(
		_menu_player.volume_db,
		_menu_target_db,
		FADE_DB_PER_SECOND * delta
	)
	_battle_player.volume_db = move_toward(
		_battle_player.volume_db,
		_battle_target_db,
		FADE_DB_PER_SECOND * delta
	)
	if _menu_player.volume_db <= SILENT_DB and _menu_target_db <= SILENT_DB:
		_menu_player.stop()
	if _battle_player.volume_db <= SILENT_DB and _battle_target_db <= SILENT_DB:
		_battle_player.stop()


func play_menu(immediate: bool = false) -> void:
	if _active_mode == &"menu":
		return
	_active_mode = &"menu"
	_menu_target_db = MENU_DB
	_battle_target_db = SILENT_DB
	_start_from_beginning(_menu_player)
	if immediate:
		_menu_player.volume_db = MENU_DB
		_battle_player.volume_db = SILENT_DB
		_battle_player.stop()


func play_battle() -> void:
	if _active_mode == &"battle":
		return
	_active_mode = &"battle"
	_menu_target_db = SILENT_DB
	_battle_target_db = BATTLE_DB
	_start_from_beginning(_battle_player)


func _create_player(stream: AudioStream, player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"BGM"
	player.stream = stream
	player.volume_db = SILENT_DB
	add_child(player)
	return player


func _looped_copy(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * float(stream.mix_rate))
	return stream


func _start_from_beginning(player: AudioStreamPlayer) -> void:
	player.stop()
	player.volume_db = SILENT_DB
	player.play()
