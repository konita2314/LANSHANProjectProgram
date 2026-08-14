## SceneGallery : Control
## 场景/背景画廊屏幕 — 所有场景图片的2列卡片网格。
## 平面列表（无分区分组）。点击卡片打开 PictureViewer。
extends Control

signal back_requested()
signal picture_requested(entries: Array[Dictionary], start_index: int)

# ---------------------------------------------------------------------------
# 状态
# ---------------------------------------------------------------------------
var _entries: Array[Dictionary] = []   # [{file, name}]
var _focus_idx: int = 0
var _disabled: bool = false
var _card_nodes: Array[Control] = []
var _back_bar: BackBar = null

# 字体引用

const GRID_COLS: int = 2
const CARD_WIDTH: float = 540.0
const CARD_HEIGHT: float = 110.0
const GRID_GAP: float = 16.0

# ---------------------------------------------------------------------------
# 就绪时
# ---------------------------------------------------------------------------
@onready var _title_label: Label = %TitleLabel
@onready var _content_container: VBoxContainer = %ContentContainer
@onready var _gallery_scroll: ScrollContainer = $GalleryScroll


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:
	_setup()
	_animate_enter()


func _on_enter() -> void:
	_disabled = false
	if _back_bar:
		_back_bar.set_language()
	_update_focus()


func _on_exit() -> void:
	_disabled = true


# ===================================================================
# 设置
# ===================================================================

func _setup() -> void:


	_title_label.text = "Gallary"
	_title_label.add_theme_font_size_override("font_size", 72)
	if GameManager.font_tcm: _title_label.add_theme_font_override("font", GameManager.font_tcm)

	# 无页面副标题 — 标题 "Gallary" 已足够

		# 将所有场景图片加载为平面列表（运行时扫描派生，无需手动同步）
	var scene_data: RefCounted = preload("res://scripts/gallery/SceneGalleryData.gd")
	_entries.assign(scene_data.get_flat_entries())

	_create_cards()
	_setup_back_button()


# ===================================================================
# 卡片创建（MusicGallery 风格）
# ===================================================================

func _create_cards() -> void:
	# 清除现有内容，创建单个平面 GridContainer
	for c: Node in _content_container.get_children():
		c.queue_free()

	var grid := GridContainer.new()
	grid.name = "SceneGrid"
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", int(GRID_GAP))
	grid.add_theme_constant_override("v_separation", int(GRID_GAP))
	grid.size_flags_horizontal = Control.SIZE_FILL
	_content_container.add_child(grid)

	for i: int in range(_entries.size()):
		var card: Control = _make_card(i)
		grid.add_child(card)
		_card_nodes.append(card)
	_update_focus()


func _make_card(idx: int) -> Control:
	var entry: Dictionary = _entries[idx]

	var card := Control.new()
	card.name = "Card_" + str(idx)
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# ── 图层 0：背景填充 ──
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.15, 0.15, 0.15, 0.8)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(fill)

	# ── 图层 2：序号水印 ──
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

	# ── 图层 3：场景名称（中文显示名）──
	var title_zh := Label.new()
	title_zh.name = "TitleZH"
	title_zh.text = entry.name
	title_zh.position = Vector2(88, 24)
	title_zh.size = Vector2(CARD_WIDTH - 104, 28)
	title_zh.add_theme_font_size_override("font_size", 24)
	title_zh.add_theme_color_override("font_color", Color.WHITE)
	title_zh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_zh.clip_text = true
	if GameManager.font_tcm: title_zh.add_theme_font_override("font", GameManager.font_tcm)
	card.add_child(title_zh)

	# ── 存储元数据 ──
	card.set_meta("fill", fill)
	card.set_meta("title_zh", title_zh)
	card.set_meta("num", num)

	# ── 信号连接 ──
	card.mouse_entered.connect(_on_hover.bind(idx))
	card.gui_input.connect(_on_card_clicked.bind(idx))

	return card


# ===================================================================
# 焦点与动画
# ===================================================================

func _update_focus(p_scroll: bool = false) -> void:
	if _card_nodes.is_empty():
		return
	_focus_idx = clampi(_focus_idx, 0, _card_nodes.size() - 1)

	for i: int in range(_card_nodes.size()):
		var card: Control = _card_nodes[i]
		var is_focused: bool = i == _focus_idx

		# 终止此卡片上任何正在运行的 tween
		if card.has_meta("focus_tween"):
			var tw: Tween = card.get_meta("focus_tween") as Tween
			if tw and tw.is_valid():
				tw.kill()

		var fill: ColorRect = card.get_meta("fill")

		var target_fill: Color = Color(0.35, 0.35, 0.35, 0.85) if is_focused else Color(0.15, 0.15, 0.15, 0.8)
		var target_scale: float = 1.02 if is_focused else 1.0

		var t := create_tween().set_parallel(true)
		t.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_property(fill, "color", target_fill, 0.25)
		t.tween_property(card, "scale", Vector2(target_scale, target_scale), 0.2)

		card.set_meta("focus_tween", t)

	if p_scroll and _focus_idx >= 0:
		var focused_card: Control = _card_nodes[_focus_idx]
		_gallery_scroll.ensure_control_visible(focused_card)


func _on_hover(index: int) -> void:
	if _disabled or _focus_idx == index:
		return
	_focus_idx = index
	_update_focus()
	_play_click()


# ===================================================================
# 卡片交互
# ===================================================================

func _on_card_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_open_picture_viewer(index)


func _open_picture_viewer(index: int) -> void:
	if _disabled:
		return
	if index < 0 or index >= _entries.size():
		return

	_play_click()
	# 传递所有条目（平面列表）—— 查看器可浏览完整列表
	picture_requested.emit(_entries, index)


# ===================================================================
# 返回按钮栏（MusicGallery / RewardsScene 风格）
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
		_open_picture_viewer(_focus_idx)
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
# 公共方法
# ===================================================================

func set_disabled(val: bool) -> void:
	_disabled = val
