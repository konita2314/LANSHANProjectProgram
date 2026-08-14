## VNAudioService : Node (Autoload)
## VN 场景专用音频管理 — BGM 双轨交叉淡入淡出 + 多层环境音。
## 与 AudioManager 分工：AudioManager 负责全局 UI 音效和音量控制，
## VNAudioService 负责 VN 剧情中的 BGM / 环境音播放及过渡。
##
## 总线设计：
##   BGM       — 双播放器 A/B 交替，支持交叉淡入淡出（bus "BGM" → fallback "Master"）
##   Ambience  — 最多 4 层独立环境音循环（bus "Ambience" → fallback BGM bus）
##   SFX       — 委托给 AudioManager.play_sfx() / AudioManager.play_click()
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const DEFAULT_CROSSFADE: float = 1.5
const MAX_AMBIENCE_LAYERS: int = 4

# ---------------------------------------------------------------------------
# BGM — 双播放器 A/B 交替，支持无缝交叉淡入淡出
# ---------------------------------------------------------------------------
var _bgm_a: AudioStreamPlayer = null
var _bgm_b: AudioStreamPlayer = null
var _active_bgm_player: AudioStreamPlayer = null   # 当前正在输出的播放器
var _inactive_bgm_player: AudioStreamPlayer = null  # 备用播放器（用于下一首淡入）
var _current_bgm_path: String = ""
var _crossfade_tween: Tween = null
var _stop_timer_tween: Tween = null

# ---------------------------------------------------------------------------
# 环境音 — 最多 4 层独立循环层，用于风、雨、虫鸣等环境声
# ---------------------------------------------------------------------------
var _ambience_layers: Array[AudioStreamPlayer] = []
var _ambience_paths: Array[String] = []
var _ambience_fade_tweens: Array[Tween] = []

# ---------------------------------------------------------------------------
# BGM 播放位置记忆（用于存档恢复）
# ---------------------------------------------------------------------------
var _bgm_playback_position: float = 0.0

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------

func _ready() -> void:
	var bgm_bus: String = "BGM" if AudioServer.get_bus_index("BGM") != -1 else "Master"

	_bgm_a = _make_player("VNAS_BGM_A", bgm_bus)
	_bgm_b = _make_player("VNAS_BGM_B", bgm_bus)
	_active_bgm_player = _bgm_a
	_inactive_bgm_player = _bgm_b

	for i in MAX_AMBIENCE_LAYERS:
		var p := _make_player("VNAS_Ambience_" + str(i), "Ambience" if AudioServer.get_bus_index("Ambience") != -1 else bgm_bus)
		p.volume_db = -80.0  # silent by default
		_ambience_layers.append(p)
		_ambience_paths.append("")
	_ambience_fade_tweens.resize(MAX_AMBIENCE_LAYERS)


func _make_player(p_name: String, p_bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = p_name
	p.bus = p_bus
	add_child(p)
	return p


# ===================================================================
# BGM — 直接切换（0.15s 快速交叉淡入淡出）
# ===================================================================

## 播放 BGM，通过 A/B 双轨以 0.15s 快速交叉淡入淡出切换。
## 同曲目且已在播放时忽略。
func play_bgm(path: String, loop: bool = true) -> void:
	_kill_crossfade_tween()
	if _current_bgm_path == path and _active_bgm_player.playing:
		return
	var stream := AudioManager.load_stream(path, "music")
	if not stream:
		return

	# 交换 active/inactive，在备用播放器上启动新曲目
	var old_player: AudioStreamPlayer = _active_bgm_player
	var new_player: AudioStreamPlayer = _inactive_bgm_player

	new_player.stop()
	@warning_ignore("static_called_on_instance")
	AudioManager.configure_loop(stream, loop)
	new_player.stream = stream
	new_player.volume_db = linear_to_db(0.001)
	new_player.play()

	_current_bgm_path = path
	_bgm_playback_position = 0.0

	# 0.15s 交叉淡入淡出：旧轨淡出，新轨淡入
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	_crossfade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if old_player.playing:
		_crossfade_tween.tween_property(old_player, "volume_db", linear_to_db(0.001), 0.15)
		# 延时 0.2s 后停止旧播放器，避免 play_bgm/stop_bgm 快速连续调用时误停当前活跃轨
		_stop_timer_tween = create_tween()
		_stop_timer_tween.tween_callback(old_player.stop).set_delay(0.2)

	_crossfade_tween.tween_method(_set_player_volume.bind(new_player), 0.0, 1.0, 0.15)

	# 交换指针
	_active_bgm_player = new_player
	_inactive_bgm_player = old_player


func stop_bgm() -> void:
	_kill_crossfade_tween()
	if _active_bgm_player.playing:
		_stop_timer_tween = create_tween()
		_stop_timer_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_stop_timer_tween.tween_property(_active_bgm_player, "volume_db", linear_to_db(0.001), 0.1)
		_stop_timer_tween.tween_callback(_active_bgm_player.stop)
	if _inactive_bgm_player.playing:
		_inactive_bgm_player.stop()
	_current_bgm_path = ""
	_bgm_playback_position = 0.0


# ===================================================================
# BGM — 交叉淡入淡出 crossfade
# ===================================================================

## 以可配置时长交叉淡入淡出切换 BGM。
## @param path          新 BGM 路径（空字符串 = 仅淡出当前曲目）
## @param fade_out_sec  旧 BGM 淡出时长，默认 1.5 秒
## @param fade_in_sec   新 BGM 淡入时长，默认 1.5 秒
func crossfade_bgm(path: String, fade_out_sec: float = DEFAULT_CROSSFADE, fade_in_sec: float = DEFAULT_CROSSFADE) -> void:
	_kill_crossfade_tween()

	if path.is_empty():
		fade_out_bgm(fade_out_sec)
		return

	var stream := AudioManager.load_stream(path, "music")
	if not stream:
		fade_out_bgm(fade_out_sec)
		return

	# Swap active/inactive
	var old_player: AudioStreamPlayer = _active_bgm_player
	var new_player: AudioStreamPlayer = _inactive_bgm_player

	new_player.stop()
	@warning_ignore("static_called_on_instance")
	AudioManager.configure_loop(stream, true)
	new_player.stream = stream
	new_player.volume_db = linear_to_db(0.001)
	new_player.play()

	_current_bgm_path = path
	_bgm_playback_position = 0.0

	# 交叉淡入淡出：旧轨淡出，延时后停止；新轨淡入
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	_crossfade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 淡出旧 BGM
	if old_player.playing:
		_crossfade_tween.tween_property(old_player, "volume_db", linear_to_db(0.001), fade_out_sec)
		# 延时停止旧播放器，避免提前停止导致爆音
		_stop_timer_tween = create_tween()
		_stop_timer_tween.tween_callback(old_player.stop).set_delay(fade_out_sec + 0.05)

	# 淡入新 BGM
	_crossfade_tween.tween_method(_set_player_volume.bind(new_player), 0.0, 1.0, fade_in_sec)

	# 交换指针
	_active_bgm_player = new_player
	_inactive_bgm_player = old_player


## 以指定时长淡入 BGM（不淡出当前曲目，直接覆盖）。
## 同曲目且已在播放时忽略。
func fade_in_bgm(path: String, duration: float = 2.0) -> void:
	_kill_crossfade_tween()

	var stream := AudioManager.load_stream(path, "music")
	if not stream:
		return

	if _current_bgm_path == path and _active_bgm_player.playing:
		return

	_active_bgm_player.stop()
	@warning_ignore("static_called_on_instance")
	AudioManager.configure_loop(stream, true)
	_current_bgm_path = path
	_active_bgm_player.stream = stream
	_active_bgm_player.volume_db = linear_to_db(0.001)
	_active_bgm_player.play()
	_bgm_playback_position = 0.0

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_player_volume.bind(_active_bgm_player), 0.0, 1.0, duration)


## 淡出当前 BGM 并停止。
func fade_out_bgm(duration: float = 2.0) -> void:
	_kill_crossfade_tween()
	if not _active_bgm_player.playing:
		return

	var player_to_fade: AudioStreamPlayer = _active_bgm_player
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player_to_fade, "volume_db", linear_to_db(0.001), duration)
	tw.tween_callback(player_to_fade.stop)
	_current_bgm_path = ""
	_bgm_playback_position = 0.0


# ===================================================================
# 环境音
# ===================================================================

## 设置指定层的环境音。
## 同路径仅更新音量；空路径则淡出并清除该层。
## @param layer   层索引 (0 ~ MAX_AMBIENCE_LAYERS - 1)
## @param path    音频路径
## @param volume  音量 0.0 ~ 1.0，默认 0.2
func set_ambience_layer(layer: int, path: String, volume: float = 0.2) -> void:
	if layer < 0 or layer >= MAX_AMBIENCE_LAYERS:
		return

	var player: AudioStreamPlayer = _ambience_layers[layer]
	var old_path: String = _ambience_paths[layer]

	if path == old_path and not path.is_empty():
		# 同路径仅调节音量
		_set_ambience_volume(player, volume)
		return

	# 杀掉当前层可能正在进行的 fade-out tween，
	# 避免 tween 将 volume_db 拉到 -60dB 后覆盖新 ambience 的动态音量。
	_kill_ambience_fade_tween(layer)

	_ambience_paths[layer] = path

	if path.is_empty():
		_fade_out_player(player, 1.0)
		return

	var stream := AudioManager.load_stream(path, "ambience")
	if not stream:
		return

	player.stop()
	@warning_ignore("static_called_on_instance")
	AudioManager.configure_loop(stream, true)
	player.stream = stream
	player.volume_db = linear_to_db(0.001)
	player.play()
	_set_ambience_volume(player, volume)


## 淡出并清除指定层的环境音。
func clear_ambience_layer(layer: int, fade_sec: float = 1.0) -> void:
	if layer < 0 or layer >= MAX_AMBIENCE_LAYERS:
		return
	var player: AudioStreamPlayer = _ambience_layers[layer]
	_ambience_paths[layer] = ""
	if not player.playing:
		return

	# 杀掉旧 tween 防止多层淡出冲突
	_kill_ambience_fade_tween(layer)
	var tw := create_tween()
	_ambience_fade_tweens[layer] = tw
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "volume_db", linear_to_db(0.001), fade_sec)
	tw.tween_callback(player.stop)
	# tween 完成后自动清空引用
	tw.finished.connect(_on_ambience_fade_finished.bind(layer), CONNECT_ONE_SHOT)


func _kill_ambience_fade_tween(layer: int) -> void:
	if layer >= 0 and layer < _ambience_fade_tweens.size():
		var tw: Tween = _ambience_fade_tweens[layer]
		if tw and tw.is_valid():
			tw.kill()
		_ambience_fade_tweens[layer] = null


func _on_ambience_fade_finished(layer: int) -> void:
	if layer >= 0 and layer < _ambience_fade_tweens.size():
		_ambience_fade_tweens[layer] = null


## 淡出并清除所有环境音层。
func clear_all_ambience(fade_sec: float = 1.0) -> void:
	for i in MAX_AMBIENCE_LAYERS:
		clear_ambience_layer(i, fade_sec)


# ===================================================================
# 存档 / 恢复
# ===================================================================

## 获取当前音频状态用于存档。
func get_audio_state() -> Dictionary:
	var state: Dictionary = {
		"bgm_path": _current_bgm_path,
		"bgm_position": _active_bgm_player.get_playback_position() if _active_bgm_player.playing else 0.0,
	}
	for i in MAX_AMBIENCE_LAYERS:
		if not _ambience_paths[i].is_empty():
			state["ambience_" + str(i)] = {
				"path": _ambience_paths[i],
				"volume": db_to_linear(_ambience_layers[i].volume_db),
			}
	return state


## 从存档恢复音频状态。
func restore_audio_state(state: Dictionary) -> void:
	if state.is_empty():
		return

	# 恢复 BGM 及其播放位置
	var bgm_path: String = state.get("bgm_path", "")
	if not bgm_path.is_empty():
		play_bgm(bgm_path, true)
		var pos: float = state.get("bgm_position", 0.0)
		if _active_bgm_player.playing and pos > 0.0:
			_active_bgm_player.seek(pos)

	# 恢复各层环境音
	for i in MAX_AMBIENCE_LAYERS:
		var key: String = "ambience_" + str(i)
		if state.has(key):
			var layer_data: Dictionary = state[key]
			set_ambience_layer(i, layer_data.get("path", ""), layer_data.get("volume", 0.5))


# ===================================================================
# 内部工具
# ===================================================================

func _kill_crossfade_tween() -> void:
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	_crossfade_tween = null
	if _stop_timer_tween and _stop_timer_tween.is_valid():
		_stop_timer_tween.kill()
	_stop_timer_tween = null


## 供 Tween.tween_method 回调的中间函数：将 0.0~1.0 的线性值
## 转换为 volume_db 并设置到指定播放器。
func _set_player_volume(v: float, player: AudioStreamPlayer) -> void:
	player.volume_db = linear_to_db(clamp(v, 0.001, 1.0))


func _set_ambience_volume(player: AudioStreamPlayer, volume: float) -> void:
	player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))


func _fade_out_player(player: AudioStreamPlayer, duration: float) -> void:
	if not player.playing:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "volume_db", linear_to_db(0.001), duration)
	tw.tween_callback(player.stop)


# ===================================================================
# SFX 委托（全部转发给 AudioManager）
# ===================================================================

func play_sfx(path: String) -> void:
	AudioManager.play_sfx(path)


func stop_sfx() -> void:
	AudioManager.stop_sfx()


func play_click(path: String = AudioManager.SFX_CLICK) -> void:
	AudioManager.play_click(path)


func stop_click() -> void:
	AudioManager.stop_click()


func stop_all() -> void:
	stop_bgm()
	clear_all_ambience(0.5)
	AudioManager.stop_sfx()
	AudioManager.stop_click()
