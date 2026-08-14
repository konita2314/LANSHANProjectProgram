## MusicGallery : Control
## 音乐画廊屏幕 — 所有游戏音乐曲目组成的2列卡片网格。
## 点击或按Enter键预览曲目；再次点击停止播放。
extends Control

signal back_requested()

# ---------------------------------------------------------------------------
# 状态
# ---------------------------------------------------------------------------
var _entries: Array[Dictionary] = []
var _focus_idx: int = 0
var _disabled: bool = false
var _playing_idx: int = -1
var _card_nodes: Array[Control] = []
var _back_bar: BackBar = null
var _subtitle_label: Label = null
var _saved_bgm_path: String = ""

# 字体引用

const GRID_COLS: int = 2
const CARD_WIDTH: float = 540.0
const CARD_HEIGHT: float = 110.0
const GRID_GAP: float = 16.0

# ---------------------------------------------------------------------------
# Onready 节点引用
# ---------------------------------------------------------------------------
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_container: Control = %SubtitleContainer
@onready var _tracks_grid: GridContainer = %TracksGrid
@onready var _grid_scroll: ScrollContainer = $GridScroll


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:
	_setup()
	_animate_enter()


func _on_enter() -> void:
	_disabled = false
	_refresh_translations()
	_update_focus()


func _refresh_translations() -> void:
		if _subtitle_label:
			_subtitle_label.text = tr("游戏中出现的音乐")
		if _back_bar:
			_back_bar.set_language()


func _on_exit() -> void:
	_disabled = true
	# 返回成就页面之前，停止任何正在播放的预览并恢复菜单模式
	if _playing_idx >= 0:
		AudioManager.stop_bgm()
		AudioManager.set_menu_mode(true)
		if not _saved_bgm_path.is_empty():
			AudioManager.play_bgm(_saved_bgm_path, true)
			_saved_bgm_path = ""
		_set_playing_indicator(-1)


# ===================================================================
# 设置
# ===================================================================

func _setup() -> void:


	_title_label.text = "Music"
	_title_label.add_theme_font_size_override("font_size", 72)
	if GameManager.font_tcm: _title_label.add_theme_font_override("font", GameManager.font_tcm)

	# 副标题
	for c: Node in _subtitle_container.get_children():
		c.queue_free()
	var sub := Label.new()
	_subtitle_label = sub
	sub.text = tr("游戏中出现的音乐")
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_container.add_child(sub)

	# 网格设置
	_tracks_grid.add_theme_constant_override("h_separation", int(GRID_GAP))
	_tracks_grid.add_theme_constant_override("v_separation", int(GRID_GAP))
	_tracks_grid.columns = GRID_COLS
	_tracks_grid.size_flags_horizontal = Control.SIZE_FILL
	_tracks_grid.size_flags_vertical = Control.SIZE_FILL

	# 从预加载数据加载条目
	var music_data: RefCounted = preload("res://scripts/gallery/MusicGalleryData.gd")
	_entries.assign(music_data.ENTRIES)

	_create_cards()
	_setup_back_button()


# ===================================================================
# 卡片创建
# ===================================================================

func _create_cards() -> void:
	for i: int in range(_entries.size()):
		var card: Control = _make_card(i)
		_tracks_grid.add_child(card)
		_card_nodes.append(card)
	_update_focus()


func _make_card(idx: int) -> Control:
	var entry: Dictionary = _entries[idx]

	var card := Control.new()
	card.name = "Track_" + str(idx)
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# ── 图层 0：背景填充 ──
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.15, 0.15, 0.15, 0.8)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(fill)

	# ── 图层 2：曲目编号水印 ──
	var num := Label.new()
	num.name = "Number"
	num.text = "%02d" % (idx + 1)
	num.position = Vector2(16, 20)
	num.size = Vector2(60, 52)
	num.add_theme_font_size_override("font_size", 52)
	num.add_theme_color_override("font_color", Color(1, 1, 1, 0.08))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_tcm: num.add_theme_font_override("font", GameManager.font_tcm)
	card.add_child(num)


	# ── 图层 4：英文标题 ──
	var title_en := Label.new()
	title_en.name = "TitleEN"
	title_en.text = entry.title
	title_en.position = Vector2(88, 32)
	title_en.size = Vector2(CARD_WIDTH - 104, 30)
	title_en.add_theme_font_size_override("font_size", 26)
	title_en.add_theme_color_override("font_color", Color.WHITE)
	title_en.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_tcm: title_en.add_theme_font_override("font", GameManager.font_tcm)
	card.add_child(title_en)

	# ── 图层 5：播放指示器 ──
	var playing := Label.new()
	playing.name = "Playing"
	playing.text = "▶ NOW PLAYING"
	playing.position = Vector2(CARD_WIDTH - 200, 54)
	playing.size = Vector2(180, 20)
	playing.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	playing.add_theme_font_size_override("font_size", 14)
	playing.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	playing.visible = false
	if GameManager.font_tcm: playing.add_theme_font_override("font", GameManager.font_tcm)
	card.add_child(playing)

	# ── 存储元数据 ──
	card.set_meta("fill", fill)
	card.set_meta("title_en", title_en)
	card.set_meta("playing", playing)
	card.set_meta("num", num)

	# ── 信号连接 ──
	card.mouse_entered.connect(_on_hover.bind(idx))
	card.mouse_exited.connect(_on_unhover)
	card.gui_input.connect(_on_card_clicked.bind(idx))

	return card


# ===================================================================
# 焦点与动画
# ===================================================================

func _update_focus(p_scroll: bool = false) -> void:
	if _card_nodes.is_empty():
		return
	if _focus_idx >= 0:
		_focus_idx = clampi(_focus_idx, 0, _card_nodes.size() - 1)

	for i: int in range(_card_nodes.size()):
		var card: Control = _card_nodes[i]
		var is_focused: bool = i == _focus_idx

		# 终止此卡片上正在运行的任何 tween
		if card.has_meta("focus_tween"):
			var tw: Tween = card.get_meta("focus_tween") as Tween
			if tw and tw.is_valid():
				tw.kill()

		var fill: ColorRect = card.get_meta("fill")
		var _title_en: Label = card.get_meta("title_en")
		var _num: Label = card.get_meta("num")

		var target_fill: Color = Color(0.35, 0.35, 0.35, 0.85) if is_focused else Color(0.15, 0.15, 0.15, 0.8)
		var target_scale: float = 1.02 if is_focused else 1.0

		var t := create_tween().set_parallel(true)
		t.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_property(fill, "color", target_fill, 0.25)
		t.tween_property(card, "scale", Vector2(target_scale, target_scale), 0.2)

		card.set_meta("focus_tween", t)

	if p_scroll and _focus_idx >= 0:
		var focused_card: Control = _card_nodes[_focus_idx]
		_grid_scroll.ensure_control_visible(focused_card)



func _on_hover(index: int) -> void:
	if _disabled or _focus_idx == index:
		return
	_focus_idx = index
	_update_focus()
	_play_click()


func _on_unhover() -> void:
	if _disabled:
		return
	_focus_idx = -1
	_update_focus()


# ===================================================================
# 卡片交互
# ===================================================================

func _on_card_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_play(index)


func _toggle_play(index: int) -> void:
	if _disabled:
		return
	_play_click()

	var entry: Dictionary = _entries[index]

	if _playing_idx == index:
		# 停止当前预览 — 恢复菜单音频模糊效果
		AudioManager.stop_bgm()
		AudioManager.set_menu_mode(true)
		if not _saved_bgm_path.is_empty():
			AudioManager.play_bgm(_saved_bgm_path, true)
			_saved_bgm_path = ""
		_set_playing_indicator(-1)
		return

	# 在替换之前保存当前 BGM（仅在第一次预览时）
	if _playing_idx < 0:
		_saved_bgm_path = AudioManager._current_bgm_path
	# 如果从另一首曲目切换，先停止前一首
	if _playing_idx >= 0:
		AudioManager.stop_bgm()

	# 进入预览模式 — 移除菜单低通滤镜，循环播放
	AudioManager.set_menu_mode(false)
	var file: String = entry.file
	AudioManager.play_bgm(file, true)
	_set_playing_indicator(index)


func _set_playing_indicator(index: int) -> void:
	# 隐藏前一个指示器
	if _playing_idx >= 0 and _playing_idx < _card_nodes.size():
		var old_card: Control = _card_nodes[_playing_idx]
		var old_playing: Label = old_card.get_meta("playing")
		if old_playing: old_playing.visible = false

	_playing_idx = index

	# 显示新指示器
	if index >= 0 and index < _card_nodes.size():
		var new_card: Control = _card_nodes[index]
		var new_playing: Label = new_card.get_meta("playing")
		if new_playing: new_playing.visible = true


# ===================================================================
# 返回按钮栏
# ===================================================================

func _setup_back_button() -> void:
	_back_bar = BackBar.attach(self, _on_back_pressed)


func _on_back_pressed() -> void:
	back_requested.emit()


# ===================================================================
# 输入 — 键盘导航
# ===================================================================

func _input(event: InputEvent) -> void:
	if _disabled or not event.is_pressed():
		return

	if event.is_action_pressed("ui_up"):
		_focus_idx = maxi(0, _focus_idx - GRID_COLS)
		_update_focus(true)
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_focus_idx = mini(_card_nodes.size() - 1, _focus_idx + GRID_COLS)
		_update_focus(true)
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_focus_idx = maxi(0, _focus_idx - 1)
		_update_focus(true)
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_focus_idx = mini(_card_nodes.size() - 1, _focus_idx + 1)
		_update_focus(true)
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_toggle_play(_focus_idx)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_play_click()
		back_requested.emit()
		get_viewport().set_input_as_handled()


# ===================================================================
# 动画
# ===================================================================

func _animate_enter() -> void:
	@warning_ignore("static_called_on_instance")
	GameManager.animate_scene_enter(self)


# ===================================================================
# 音频
# ===================================================================

func _play_click() -> void:
	AudioManager.play_click()


# ===================================================================
# 公共接口
# ===================================================================

func set_disabled(val: bool) -> void:
	_disabled = val
