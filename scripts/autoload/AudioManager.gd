## AudioManager : Node (Autoload)
## 全局音频播放单例 — 四个独立音轨：
##   1. BGM        — 背景音乐（主菜单，VN 中由 VNAudioService 接管）
##   2. SFX        — 短一次性音效
##   3. Click      — UI 点击音效（始终单次播放，从不阻塞任何内容）
## 每个音轨一个专用播放器 — 三个可以同时播放。
## Ambience 环境音循环由 VNAudioService 管理。
extends Node

const SFX_CLICK: String = "res://assets/sfx/Choose.ogg"
# 音频播放器 — 每个独立音轨一个
var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer          # 短一次性音效
var _click_player: AudioStreamPlayer

# 效果总线索引
var _master_bus_idx: int
var _bgm_bus_idx: int
var _ambience_bus_idx: int
var _sfx_bus_idx: int
var _click_bus_idx: int

# State
var _current_bgm_path: String = ""
var _initialized: bool = false


func _ready() -> void:
	# 确保音频总线存在（如果不存在则创建）
	_master_bus_idx = AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_index("BGM") == -1:
		AudioServer.add_bus(_master_bus_idx + 1)
		AudioServer.set_bus_name(_master_bus_idx + 1, "BGM")
	if AudioServer.get_bus_index("Ambience") == -1:
		AudioServer.add_bus(_master_bus_idx + 2)
		AudioServer.set_bus_name(_master_bus_idx + 2, "Ambience")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(_master_bus_idx + 3)
		AudioServer.set_bus_name(_master_bus_idx + 3, "SFX")
	if AudioServer.get_bus_index("Click") == -1:
		AudioServer.add_bus(_master_bus_idx + 4)
		AudioServer.set_bus_name(_master_bus_idx + 4, "Click")

	_bgm_bus_idx = AudioServer.get_bus_index("BGM")
	_ambience_bus_idx = AudioServer.get_bus_index("Ambience")
	_sfx_bus_idx = AudioServer.get_bus_index("SFX")
	_click_bus_idx = AudioServer.get_bus_index("Click")

	_bgm_player = _make_player("BGMPlayer", "BGM")
	_sfx_player = _make_player("SFXPlayer", "SFX")
	_click_player = _make_player("ClickPlayer", "Click")

	_initialized = true


func _make_player(p_name: String, p_bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = p_name
	p.bus = p_bus
	add_child(p)
	return p


# ===================================================================
# Volume
# ===================================================================

func unlock_audio() -> void:
	apply_volumes()


func apply_volumes() -> void:
	var s := GameManager.get_settings()
	AudioServer.set_bus_volume_db(_master_bus_idx, linear_to_db(s.master_volume))
	if _bgm_bus_idx != _master_bus_idx:
		AudioServer.set_bus_volume_db(_bgm_bus_idx, linear_to_db(s.bgm_volume * s.master_volume))
	if _ambience_bus_idx != _master_bus_idx:
		AudioServer.set_bus_volume_db(_ambience_bus_idx, linear_to_db(s.ambience_volume * s.master_volume))
	if _sfx_bus_idx != _master_bus_idx:
		AudioServer.set_bus_volume_db(_sfx_bus_idx, linear_to_db(s.sfx_volume * s.master_volume))
	if _click_bus_idx != _master_bus_idx:
		AudioServer.set_bus_volume_db(_click_bus_idx, linear_to_db(s.sfx_volume * s.master_volume))


# ===================================================================
# BGM
# ===================================================================

func play_bgm(path: String, loop: bool = true) -> void:
	if not _initialized:
		return
	if _current_bgm_path == path and _bgm_player.playing:
		return

	var stream := load_stream(path, "music")
	if not stream:
		return

	if _bgm_player.playing:
		_bgm_player.stop()

	configure_loop(stream, loop)
	_current_bgm_path = path
	_bgm_player.stream = stream
	_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player.playing:
		_bgm_player.stop()
	_current_bgm_path = ""


# ===================================================================
# SFX — 短一次性音效
# ===================================================================

func play_sfx(path: String) -> void:
	if not _initialized:
		return
	var stream := load_stream(path, "sfx")
	if not stream:
		return
	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.play()


func stop_sfx() -> void:
	if _sfx_player.playing:
		_sfx_player.stop()


# ===================================================================
# Click — UI 点击音效（专用播放器 + 总线，从不阻塞 SFX）
# ===================================================================

## 播放一个单次点击/UI 音效。使用 "Click" 总线上的专用播放器，
## 因此它从不中断 "SFX" 总线上的音效。
func play_click(path: String = SFX_CLICK) -> void:
	if not _initialized:
		return
	var stream := load_stream(path, "sfx")
	if not stream:
		return
	_click_player.stop()
	_click_player.stream = stream
	_click_player.play()


func stop_click() -> void:
	if _click_player.playing:
		_click_player.stop()


# ===================================================================
# All
# ===================================================================

func stop_all() -> void:
	stop_bgm()
	stop_sfx()
	stop_click()


# ===================================================================
# 菜单模式 — 当子菜单覆盖 VN 时减弱 BGM 和 Ambience。
# 平滑过渡低通滤波器以获得"湿润"感。
# SFX 和 Click 不受影响。
# ===================================================================

const MENU_LP_CUTOFF: float = 800.0    # 菜单模式下的低通截止频率（Hz）
const MENU_LP_OPEN: float = 22000.0    # 完全开放（无过滤）
const MENU_LP_DURATION: float = 0.35   # 过渡动画持续时间

var _menu_lp_tween_bgm: Tween = null       # BGM 总线低通过渡动画
var _menu_lp_tween_ambience: Tween = null  # Ambience 总线低通过渡动画


func set_menu_mode(active: bool) -> void:
	# 对 BGM 和 Ambience 两个总线同时应用低通滤波器
	# （新 tween 须写回成员变量，否则下次调用无法终止进行中的过渡）
	_menu_lp_tween_bgm = _apply_menu_lp_to_bus(_bgm_bus_idx, active, _menu_lp_tween_bgm)
	_menu_lp_tween_ambience = _apply_menu_lp_to_bus(_ambience_bus_idx, active, _menu_lp_tween_ambience)


## 在指定总线上确保存在 LowPassFilter，并平滑过渡其截止频率。
## 返回新创建的过渡 Tween（无总线时原样返回传入值），供调用方保存。
func _apply_menu_lp_to_bus(bus_idx: int, active: bool, current_tween: Tween) -> Tween:
	if bus_idx == -1:
		return current_tween

	# 确保总线上存在 LowPassFilter 效果
	var lp_index: int = -1
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectLowPassFilter:
			lp_index = i
			break
	if lp_index == -1:
		var new_lp := AudioEffectLowPassFilter.new()
		new_lp.cutoff_hz = MENU_LP_OPEN
		new_lp.resonance = 0.2
		AudioServer.add_bus_effect(bus_idx, new_lp)
		lp_index = AudioServer.get_bus_effect_count(bus_idx) - 1

	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus_idx, lp_index) as AudioEffectLowPassFilter
	if lp == null:
		return current_tween

	# 终止任何进行中的过渡，使新目标生效
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	var target_hz: float = MENU_LP_CUTOFF if active else MENU_LP_OPEN
	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_method(_set_lp_cutoff.bind(lp), lp.cutoff_hz, target_hz, MENU_LP_DURATION)
	return current_tween


## tween_method 回调 — 平滑设置低通截止频率。
func _set_lp_cutoff(hz: float, lp: AudioEffectLowPassFilter) -> void:
	lp.cutoff_hz = hz


# ===================================================================
# Glitch 效果
# ===================================================================

func set_vn_effect(_intensity: float) -> void:
	pass


func update_glitch_effect(progress: float) -> void:
	# 对 BGM 和 Ambience 总线同时应用 glitch 低通滤波器
	_apply_glitch_lp_to_bus(_bgm_bus_idx, progress)
	_apply_glitch_lp_to_bus(_ambience_bus_idx, progress)

	var s := GameManager.get_settings()
	var v := s.bgm_volume * s.master_volume * (1.0 - pow(progress, 3))
	if progress >= 1.0:
		stop_bgm()
	else:
		AudioServer.set_bus_volume_db(_bgm_bus_idx, linear_to_db(max(0.001, v)))


func _apply_glitch_lp_to_bus(bus_idx: int, progress: float) -> void:
	if bus_idx == -1:
		return
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var fx := AudioServer.get_bus_effect(bus_idx, i)
		if fx is AudioEffectLowPassFilter:
			var freq := 22000.0 * pow(1.0 - progress, 4)
			(fx as AudioEffectLowPassFilter).cutoff_hz = max(100.0, freq)


func reset_effects() -> void:
	set_menu_mode(false)
	apply_volumes()


# ===================================================================
# 音频流加载 — 公共接口（VNAudioService 复用，勿降为私有）
# ===================================================================

## 加载音频流 — Web 风格路径规范化 + AssetResolver 短名回退。
## type_hint: "sfx" / "music" / "ambience" / ""（任意）。
func load_stream(path: String, type_hint: String = "") -> AudioStream:
	if path.is_empty():
		return null

	# 规范化 Web 风格路径
	var normalized: String = AssetResolver.normalize_web_path(path)

	# Try direct load first
	if ResourceLoader.exists(normalized):
		var res := load(normalized)
		if res is AudioStream:
			return res
		push_warning("AudioManager: not an AudioStream — ", path)
		return null

	# Fallback: try AssetResolver for non-res:// paths (regardless of slashes)
	if not normalized.begins_with("res://"):
		var resolved: String
		match type_hint:
			"sfx": resolved = AssetResolver.resolve_sfx(path)
			"music": resolved = AssetResolver.resolve_music(path)
			"ambience": resolved = AssetResolver.resolve_ambience(path)
			_: resolved = AssetResolver.resolve_any(path)
		if resolved != path and ResourceLoader.exists(resolved):
			var res := load(resolved)
			if res is AudioStream:
				return res

	push_warning("AudioManager: could not load — ", path)
	return null


## 配置音频流循环模式（MP3 / Ogg / WAV）。
static func configure_loop(stream: AudioStream, loop: bool) -> void:
	if not loop:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
