extends Node

static var instance

const SFX_POOL_SIZE: int = 8

@export var select_screen_bgm: AudioStream
@export var battle_bgm: AudioStream

@export var round_intro_sfx: AudioStream
@export var fight_call_sfx: AudioStream
@export var ko_sfx: AudioStream
@export var match_win_sfx: AudioStream
@export var select_character_voice_sfx: AudioStream

var is_music_playing: bool:
	get: return _music_player.playing if _music_player != null else false

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _bgm_tween: Tween

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	instance = self

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	add_child(_music_player)

	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = "Master"
		add_child(player)
		_sfx_pool.append(player)

	if select_screen_bgm == null: select_screen_bgm = _load_audio_fallback(["res://Assets/Audio/BGM/menu.mp3", "res://Assets/Audio/BGM/menu.wav", "res://Assets/Audio/SFX/ddlc-select-sfx.mp3"])
	if battle_bgm == null: battle_bgm = _load_audio_fallback(["res://Assets/Audio/BGM/battle.mp3", "res://Assets/Audio/BGM/battle.wav", "res://Assets/Audio/BGM/cps2-guile-stage.mp3"])
	if round_intro_sfx == null: round_intro_sfx = _load_audio_fallback(["res://Assets/Audio/SFX/round_intro.mp3", "res://Assets/Audio/SFX/round_intro.wav", "res://Assets/Audio/SFX/appear-select.mp3"])
	if fight_call_sfx == null: fight_call_sfx = _load_audio_fallback(["res://Assets/Audio/SFX/fight.mp3", "res://Assets/Audio/SFX/fight.wav", "res://Assets/Audio/SFX/select.mp3"])
	if ko_sfx == null: ko_sfx = _load_audio_fallback(["res://Assets/Audio/SFX/ko.mp3", "res://Assets/Audio/SFX/ko.wav", "res://Assets/Audio/SFX/hover.mp3"])
	if match_win_sfx == null: match_win_sfx = select_screen_bgm
	if select_character_voice_sfx == null: select_character_voice_sfx = _load_audio_fallback(["res://Assets/Audio/SFX/choose_character.mp3", "res://Assets/Audio/SFX/choose_character.wav", "res://Assets/Audio/SFX/appear-select.mp3"])

	apply_volumes()

	if GameManager.instance != null:
		GameManager.instance.settings_changed.connect(apply_volumes)

static func _load_audio_fallback(candidate_paths: Array[String]) -> AudioStream:
	for path in candidate_paths:
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

func play_music(track: AudioStream, _loop: bool = true) -> void:
	if _bgm_tween != null:
		_bgm_tween.kill()

	if _music_player.stream == track and _music_player.playing:
		_music_player.volume_db = _get_target_music_db()
		return

	_music_player.stream = track
	_music_player.volume_db = _get_target_music_db()
	_music_player.play()

func fade_in_music(track: AudioStream, duration_seconds: float = 1.5) -> void:
	if _bgm_tween != null:
		_bgm_tween.kill()

	var target_db = _get_target_music_db()

	if _music_player.stream != track or not _music_player.playing:
		_music_player.stream = track
		_music_player.volume_db = -60.0
		_music_player.play()

	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_music_player, "volume_db", target_db, duration_seconds).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

func fade_out_music(duration_seconds: float = 1.5) -> void:
	if not _music_player.playing:
		return

	if _bgm_tween != null:
		_bgm_tween.kill()

	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_music_player, "volume_db", -60.0, duration_seconds).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	_bgm_tween.tween_callback(stop_music)

func stop_music() -> void:
	if _bgm_tween != null:
		_bgm_tween.kill()
	_music_player.stop()

func play_round_intro_sfx() -> void:
	if round_intro_sfx != null: play_sfx(round_intro_sfx)

func play_fight_sfx() -> void:
	if fight_call_sfx != null: play_sfx(fight_call_sfx)

func play_ko_sfx() -> void:
	if ko_sfx != null: play_sfx(ko_sfx)

func play_match_win_sfx() -> void:
	play_menu_music()

func play_select_character_voice_sfx() -> void:
	if select_character_voice_sfx != null: play_sfx(select_character_voice_sfx)

func play_menu_music() -> void:
	if select_screen_bgm != null:
		if not _music_player.playing or _music_player.stream != select_screen_bgm:
			play_music(select_screen_bgm)

func play_sfx(clip: AudioStream) -> void:
	if clip == null:
		return
	var player = _sfx_pool[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_pool.size()
	player.stream = clip
	player.pitch_scale = 1.0
	var master = GameManager.instance.settings.master_volume if GameManager.instance != null and GameManager.instance.settings != null else 1.0
	var sfx = GameManager.instance.settings.sfx_volume if GameManager.instance != null and GameManager.instance.settings != null else 1.0
	player.volume_db = _linear_to_db(master * sfx)
	player.play()

func play_sfx_pitched(clip: AudioStream, pitch_scale: float) -> void:
	if clip == null:
		return
	var player = _sfx_pool[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_pool.size()
	player.stream = clip
	player.pitch_scale = maxf(0.01, pitch_scale)
	var master = GameManager.instance.settings.master_volume if GameManager.instance != null and GameManager.instance.settings != null else 1.0
	var sfx = GameManager.instance.settings.sfx_volume if GameManager.instance != null and GameManager.instance.settings != null else 1.0
	player.volume_db = _linear_to_db(master * sfx)
	player.play()

func _get_target_music_db() -> float:
	var master = GameManager.instance.settings.master_volume if GameManager.instance != null else 1.0
	var music = GameManager.instance.settings.music_volume if GameManager.instance != null else 0.8
	return _linear_to_db(master * music)

func apply_volumes() -> void:
	_music_player.volume_db = _get_target_music_db()
	var master = GameManager.instance.settings.master_volume if GameManager.instance != null else 1.0
	var sfx = GameManager.instance.settings.sfx_volume if GameManager.instance != null else 1.0

	for player in _sfx_pool:
		player.volume_db = _linear_to_db(master * sfx)

static func _linear_to_db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.0001))
