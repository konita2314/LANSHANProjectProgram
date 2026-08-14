## Notebook : Control — 笔记本调试子场景。
## 由 SceneManager 挂载在 CanvasLayer（layer 99，仅次于 AchievementReached），
## F9 切换显示/隐藏。入场动画完全照搬 Calendar InfoPanel；
## 按下 NameLabel 可折叠/展开面板；
## GotoNext 选项的样式和动画完全参照 TabMenu 选项栏（文字左对齐）。
extends Control

signal goto_next()

# ---------------------------------------------------------------------------
# 常量
# ---------------------------------------------------------------------------
const NAME_SLIDE_DIST: float = 300.0
const NAME_SLIDE_DELAY: float = 1.0
const GOTO_REST_ALPHA: float = 0.75
const STAGGER_OFFSET: float = 50.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _is_collapsed: bool = false
var _is_visible: bool = false
var _panel_tween: Tween = null
var _goto_hover_tween: Tween = null
var _collapse_tween: Tween = null
var _name_slide_tween: Tween = null
var _name_delay_tween: Tween = null
var _fill_original_bottom: float = 0.0
var _name_rest_x: float = 0.0
var _what_rest_x: float = 0.0
var _goto_rest_x: float = 0.0
var _percent_rest_x: float = 0.0
var _hint_rest_x: float = 0.0
var _name_hovered: bool = false
var _progress: float = 0.0

# ---------------------------------------------------------------------------
# @onready 节点引用
# ---------------------------------------------------------------------------
@onready var _notebook: Control = $Notebook
@onready var _fill: Control = $Notebook/Fill
@onready var _fill_stroke: ColorRect = $Notebook/Fill/FillStroke
@warning_ignore("unused_private_class_variable")
@onready var _fill_main: ColorRect = $Notebook/Fill/FillMain
@onready var _name_label: Label = $Notebook/NameLabel
@onready var _what_you_get: Control = $Notebook/WhatYouGet
@onready var _goto_next: Label = $Notebook/GotoNext
@onready var _percent: Control = $Notebook/Percent
@onready var _percent_bar: ColorRect = $Notebook/Percent/PercentBar
@onready var _percentage_label: Label = $Notebook/Percent/Percentage
@onready var _hint: Label = $Notebook/Hint

var _goto_wrap: Control = null
var _goto_sweep: ColorRect = null
var _goto_border_style: StyleBoxFlat = null


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_fill_original_bottom = _fill.offset_bottom
	_name_rest_x = _name_label.position.x
	_what_rest_x = _what_you_get.position.x
	_percent_rest_x = _percent.position.x
	_hint_rest_x = _hint.position.x

	_apply_fonts()
	_build_goto_next()
	_setup_progress_bar()
	_connect_signals()
	_setup_name_label_style()
	_hide_immediate()


func _apply_fonts() -> void:
	@warning_ignore("static_called_on_instance")
	var name_font: Font = GameManager.select_font(_name_label.text, GameManager.font_zh_title, GameManager.font_tcm)
	if name_font:
		_name_label.add_theme_font_override("font", name_font)

	@warning_ignore("static_called_on_instance")
	var goto_font: Font = GameManager.select_font(_goto_next.text, GameManager.font_zh_title, GameManager.font_tcm)
	if goto_font:
		_goto_next.add_theme_font_override("font", goto_font)


func _setup_name_label_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(8, 6)
	sb.shadow_color = Color(1.0, 1.0, 1.0, 1.0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_name_label.add_theme_stylebox_override("normal", sb)


func _setup_progress_bar() -> void:
	# 进度条底色轨道
	var track := ColorRect.new()
	track.name = "Track"
	track.color = Color(1, 1, 1, 0.1)
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_percent.add_child(track)
	_percent.move_child(track, 0)  # track 在最底层

	# 进度条填充
	_percent_bar.color = Color(1, 1, 1, 0.85)
	_percent_bar.pivot_offset = Vector2(0, 0)
	_percent_bar.scale.x = 0.0
	_percent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 百分比文字
	_percentage_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	if GameManager.font_tcm:
		_percentage_label.add_theme_font_override("font", GameManager.font_tcm)
	_percentage_label.text = "0%"


## 设置进度条值（0.0 ~ 1.0），同步更新 bar 宽度与百分比文字。
func set_progress(pct: float) -> void:
	_progress = clampf(pct, 0.0, 1.0)
	_percent_bar.scale.x = _progress
	_percentage_label.text = "%d%%" % int(_progress * 100.0)


# ===================================================================
# GotoNext — 完全参照 TabMenu 选项样式（文字左对齐）
# ===================================================================

func _build_goto_next() -> void:
	var parent: Node = _goto_next.get_parent()

	_goto_wrap = Panel.new()
	_goto_wrap.name = "GotoNextWrap"
	_goto_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	_goto_wrap.clip_contents = true

	_goto_wrap.anchor_left = _goto_next.anchor_left
	_goto_wrap.anchor_top = _goto_next.anchor_top
	_goto_wrap.anchor_right = _goto_next.anchor_right
	_goto_wrap.anchor_bottom = _goto_next.anchor_bottom
	_goto_wrap.offset_left = _goto_next.offset_left
	_goto_wrap.offset_top = _goto_next.offset_top
	_goto_wrap.offset_right = _goto_next.offset_right
	_goto_wrap.offset_bottom = _goto_next.offset_bottom

	_goto_border_style = StyleBoxFlat.new()
	_goto_border_style.bg_color = Color(0, 0, 0, 0)
	_goto_border_style.border_width_left = 1
	_goto_border_style.border_width_right = 1
	_goto_border_style.border_width_top = 1
	_goto_border_style.border_width_bottom = 1
	_goto_border_style.border_color = Color(1, 1, 1, 0.3)
	_goto_wrap.add_theme_stylebox_override("panel", _goto_border_style)

	parent.remove_child(_goto_next)
	parent.add_child(_goto_wrap)

	_goto_sweep = ColorRect.new()
	_goto_sweep.name = "Sweep"
	_goto_sweep.color = Color.WHITE
	_goto_sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goto_sweep.scale.x = 0.0
	_goto_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goto_wrap.add_child(_goto_sweep)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goto_wrap.add_child(hb)

	_goto_next.add_theme_font_size_override("font_size", 24)
	_goto_next.add_theme_color_override("font_color", Color.WHITE)
	hb.add_child(_goto_next)

	_goto_rest_x = _goto_wrap.position.x


func _connect_signals() -> void:
	_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_label.gui_input.connect(_on_name_label_click)
	_name_label.mouse_entered.connect(_on_name_hover.bind(true))
	_name_label.mouse_exited.connect(_on_name_hover.bind(false))
	_goto_wrap.mouse_entered.connect(_on_goto_hover.bind(true))
	_goto_wrap.mouse_exited.connect(_on_goto_hover.bind(false))
	_goto_wrap.gui_input.connect(_on_goto_click)


# ===================================================================
# 输入 — F9 切换显示 / 隐藏（仅 Debug 构建）
# ===================================================================

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F9:
			if _is_visible:
				_hide_panel()
			else:
				_show_panel()
			get_viewport().set_input_as_handled()


# ===================================================================
# 显示 / 隐藏 — 入场动画完全照搬 Calendar InfoPanel
#   Panel 从右侧滑入（0.35s）
#   FillStroke border 从左展开（0.5s, delay 0.12s）
#   NameLabel 滑入 + 淡入（0.5s, delay 0.20s）
#   内容元素滑入 + 淡入（0.5s, delay 0.10s 起错峰）
# ===================================================================

func _hide_immediate() -> void:
	var vp_w: float = get_viewport().get_visible_rect().size.x
	_notebook.offset_left = vp_w
	_notebook.offset_right = vp_w

	# FillStroke border 初始不可见，FillMain 始终可见（随 panel 滑入自然展示）
	_fill_stroke.scale = Vector2(0.0, 1.0)

	# 所有 label 初始向右偏移 50px + 透明
	_name_label.position.x = _name_rest_x + STAGGER_OFFSET
	_name_label.modulate.a = 0.0
	_what_you_get.position.x = _what_rest_x + STAGGER_OFFSET
	_what_you_get.modulate.a = 0.0
	_goto_wrap.position.x = _goto_rest_x + STAGGER_OFFSET
	_goto_wrap.modulate.a = 0.0
	_percent.position.x = _percent_rest_x + STAGGER_OFFSET
	_percent.modulate.a = 0.0
	_hint.position.x = _hint_rest_x + STAGGER_OFFSET
	_hint.modulate.a = 0.0


func _show_panel() -> void:
	if _is_visible:
		return
	_is_visible = true

	_kill_panel_tween()
	_kill_collapse_tween()

	# 动态获取当前视口宽度
	var vp_w: float = get_viewport().get_visible_rect().size.x
	_notebook.offset_left = vp_w
	_notebook.offset_right = vp_w

	# ── Panel 从右侧滑入（与 InfoPanel 完全一致） ──
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(_notebook, "offset_left", 0.0, 0.35)
	_panel_tween.tween_property(_notebook, "offset_right", 0.0, 0.35)

	# ── FillStroke border 从左展开（与 InfoPanel BorderBot 完全一致） ──
	var t_border := create_tween()
	t_border.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_border.tween_property(_fill_stroke, "scale:x", 1.0, 0.5).set_delay(0.12)

	# ── NameLabel 滑入 + 淡入（与 InfoPanel 完全一致） ──
	var t_name := create_tween().set_parallel(true)
	t_name.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_name.tween_property(_name_label, "position:x", _name_rest_x, 0.5).set_delay(0.20)
	t_name.tween_property(_name_label, "modulate:a", 1.0, 0.5).set_delay(0.20)

	# ── 内容元素滑入 + 淡入（与 InfoPanel DescLabel 一致，错峰） ──
	var t_content := create_tween().set_parallel(true)
	t_content.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_content.tween_property(_what_you_get, "position:x", _what_rest_x, 0.5).set_delay(0.10)
	t_content.tween_property(_what_you_get, "modulate:a", 1.0, 0.5).set_delay(0.10)
	t_content.tween_property(_goto_wrap, "position:x", _goto_rest_x, 0.5).set_delay(0.16)
	t_content.tween_property(_goto_wrap, "modulate:a", 1.0, 0.5).set_delay(0.16)
	t_content.tween_property(_percent, "position:x", _percent_rest_x, 0.5).set_delay(0.22)
	t_content.tween_property(_percent, "modulate:a", 1.0, 0.5).set_delay(0.22)

	var t_hint := create_tween().set_parallel(true)
	t_hint.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_hint.tween_property(_hint, "position:x", _hint_rest_x, 0.5).set_delay(0.28)
	t_hint.tween_property(_hint, "modulate:a", 1.0, 0.5).set_delay(0.28)


func _hide_panel() -> void:
	if not _is_visible:
		return
	_is_visible = false

	# 如果处于折叠状态，先展开
	if _is_collapsed:
		_is_collapsed = false
		_fill.offset_top = 0.0
		_fill.offset_bottom = _fill_original_bottom

	# 复位 GotoNext hover 状态
	if _goto_hover_tween and _goto_hover_tween.is_valid():
		_goto_hover_tween.kill()
	_goto_sweep.scale.x = 0.0
	_goto_wrap.position.x = _goto_rest_x
	_goto_wrap.modulate.a = GOTO_REST_ALPHA
	_goto_next.add_theme_color_override("font_color", Color.WHITE)
	_goto_wrap.add_theme_stylebox_override("panel", _goto_border_style)

	_kill_panel_tween()
	_kill_collapse_tween()
	_kill_name_slide_delay()
	_slide_name_back()

	var vp_w: float = get_viewport().get_visible_rect().size.x

	# Panel 加速滑出（与 InfoPanel 完全一致）
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_panel_tween.tween_property(_notebook, "offset_left", vp_w, 0.30)
	_panel_tween.tween_property(_notebook, "offset_right", vp_w, 0.30)

	# 所有元素同步淡出
	_panel_tween.tween_property(_fill_stroke, "scale:x", 0.0, 0.25)
	_panel_tween.tween_property(_name_label, "modulate:a", 0.0, 0.20)
	_panel_tween.tween_property(_what_you_get, "modulate:a", 0.0, 0.20)
	_panel_tween.tween_property(_goto_wrap, "modulate:a", 0.0, 0.20)
	_panel_tween.tween_property(_percent, "modulate:a", 0.0, 0.20)
	_panel_tween.tween_property(_hint, "modulate:a", 0.0, 0.20)

	_panel_tween.chain().tween_callback(_on_hidden)


func _on_hidden() -> void:
	var vp_w: float = get_viewport().get_visible_rect().size.x
	_notebook.offset_left = vp_w
	_notebook.offset_right = vp_w
	_fill_stroke.scale = Vector2(0.0, 1.0)
	_name_label.position.x = _name_rest_x + STAGGER_OFFSET
	_what_you_get.position.x = _what_rest_x + STAGGER_OFFSET
	_goto_wrap.position.x = _goto_rest_x + STAGGER_OFFSET
	_percent.position.x = _percent_rest_x + STAGGER_OFFSET
	_hint.position.x = _hint_rest_x + STAGGER_OFFSET

	_fill.offset_top = 0.0
	_fill.offset_bottom = _fill_original_bottom
	_is_collapsed = false


# ===================================================================
# 折叠 / 展开 — "光切/抽屉"收纳流
# ===================================================================

func _on_name_label_click(event: InputEvent) -> void:
	if not _is_visible:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	AudioManager.play_click()

	if _is_collapsed:
		_expand()
	else:
		_collapse()


func _collapse() -> void:
	_is_collapsed = true

	_kill_collapse_tween()
	_slide_name_back()

	# 第一阶段：内容瞬间闪灭
	_collapse_tween = create_tween().set_parallel(true)
	_collapse_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_collapse_tween.tween_property(_what_you_get, "modulate:a", 0.0, 0.075)
	_collapse_tween.tween_property(_goto_wrap, "modulate:a", 0.0, 0.075)
	_collapse_tween.tween_property(_percent, "modulate:a", 0.0, 0.075)
	_collapse_tween.tween_property(_hint, "modulate:a", 0.0, 0.075)

	# 第二阶段：Fill 收束至 NameLabel 中轴线 + FillStroke 淡出
	var axis_y: float = _name_label.position.y + _name_label.size.y / 2.0
	_collapse_tween.tween_property(_fill, "offset_top", axis_y, 0.14).set_delay(0.075)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_collapse_tween.tween_property(_fill, "offset_bottom", axis_y, 0.14).set_delay(0.075)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_collapse_tween.tween_property(_fill_stroke, "modulate:a", 0.0, 0.10).set_delay(0.075)

	# 动画完成后 — 内容元素设为 IGNORE，防止隐形控件拦截下层鼠标事件
	_collapse_tween.chain().tween_callback(_set_content_mouse_filter.bind(Control.MOUSE_FILTER_IGNORE))


func _expand() -> void:
	_is_collapsed = false

	# 恢复内容元素鼠标交互
	_set_content_mouse_filter(Control.MOUSE_FILTER_STOP)

	_kill_collapse_tween()
	_kill_name_slide_delay()
	_slide_name_back()

	# 容器撑开 + FillStroke 淡入
	_collapse_tween = create_tween().set_parallel(true)
	_collapse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_collapse_tween.tween_property(_fill, "offset_top", 0.0, 0.32)
	_collapse_tween.tween_property(_fill, "offset_bottom", _fill_original_bottom, 0.32)
	_collapse_tween.tween_property(_fill_stroke, "modulate:a", 1.0, 0.25)

	# 内容浮现（延迟 0.30s，等 Fill 完全展开后再出现）
	_collapse_tween.tween_property(_what_you_get, "modulate:a", 1.0, 0.20).set_delay(0.30)
	_collapse_tween.tween_property(_goto_wrap, "modulate:a", 1.0, 0.20).set_delay(0.30)
	_collapse_tween.tween_property(_percent, "modulate:a", 1.0, 0.20).set_delay(0.30)
	_collapse_tween.tween_property(_hint, "modulate:a", 1.0, 0.20).set_delay(0.30)


func _set_content_mouse_filter(filter: int) -> void:
	_what_you_get.mouse_filter = filter
	_goto_wrap.mouse_filter = filter
	_percent.mouse_filter = filter
	_hint.mouse_filter = filter


# ===================================================================
# GotoNext — 完全参照 TabMenu _update_focus() 样式
# ===================================================================

func _on_goto_hover(hovered: bool) -> void:
	if not _is_visible or _is_collapsed:
		return

	if _goto_hover_tween and _goto_hover_tween.is_valid():
		_goto_hover_tween.kill()

	_goto_hover_tween = create_tween().set_parallel(true)
	_goto_hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_goto_hover_tween.tween_property(_goto_sweep, "scale:x", 1.0 if hovered else 0.0, 0.25)
	_goto_hover_tween.tween_property(_goto_wrap, "position:x", _goto_rest_x - 50.0 if hovered else _goto_rest_x + 10.0, 0.25)
	_goto_hover_tween.tween_property(_goto_wrap, "modulate:a", 1.0 if hovered else GOTO_REST_ALPHA, 0.25)

	_goto_next.add_theme_color_override("font_color", Color.BLACK if hovered else Color.WHITE)
	@warning_ignore("incompatible_ternary")
	_goto_wrap.add_theme_stylebox_override("panel", _goto_border_style if not hovered else StyleBoxEmpty.new())


func _on_goto_click(event: InputEvent) -> void:
	if not _is_visible or _is_collapsed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		AudioManager.play_click()
		goto_next.emit()


# ===================================================================
# NameLabel 折叠后自动滑出 / 鼠标悬停滑回
# ===================================================================

func _on_name_hover(hovered: bool) -> void:
	_name_hovered = hovered
	if hovered:
		if _is_collapsed:
			_kill_name_slide_delay()
			if not is_equal_approx(_name_label.position.x, _name_rest_x):
				_slide_name_back()
	else:
		if _is_collapsed and is_equal_approx(_name_label.position.x, _name_rest_x):
			_start_name_slide_delay()


func _start_name_slide_delay() -> void:
	_kill_name_slide_delay()
	_name_delay_tween = create_tween()
	_name_delay_tween.tween_interval(NAME_SLIDE_DELAY)
	_name_delay_tween.tween_callback(_slide_name_forward)


func _slide_name_forward() -> void:
	if _name_slide_tween and _name_slide_tween.is_valid():
		_name_slide_tween.kill()
	_name_slide_tween = create_tween()
	_name_slide_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_name_slide_tween.tween_property(_name_label, "position:x", _name_rest_x + NAME_SLIDE_DIST, 0.35)


func _slide_name_back() -> void:
	if _name_slide_tween and _name_slide_tween.is_valid():
		_name_slide_tween.kill()
	_name_slide_tween = create_tween()
	_name_slide_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_name_slide_tween.tween_property(_name_label, "position:x", _name_rest_x, 0.35)


func _kill_name_slide_delay() -> void:
	if _name_delay_tween and _name_delay_tween.is_valid():
		_name_delay_tween.kill()
	_name_delay_tween = null


# ===================================================================
# 动画辅助
# ===================================================================

func _kill_panel_tween() -> void:
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()


func _kill_collapse_tween() -> void:
	if _collapse_tween and _collapse_tween.is_valid():
		_collapse_tween.kill()
