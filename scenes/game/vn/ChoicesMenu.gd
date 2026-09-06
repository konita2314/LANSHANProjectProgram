## ChoicesMenu : Control
## 选择覆盖层 — 当剧情到达选择节点时显示。
##   键盘 ↑↓ 导航，Enter 确认，鼠标点击选择。
## 行本体为 scenes/ui/OptionRow 统一组件（反例形态：单文本标签，标题槽置空；
## 聚焦右移 +30、不调暗、文字色 白0.85/纯黑 经多参数 apply_focus_state 覆写）。
class_name ChoicesMenu
extends Control

signal choice_selected(index: int)

var _focused_idx: int = 0
var _option_count: int = 0
var _rows: Array[OptionRow] = []
var _is_open: bool = false


var _anim_tween: Tween = null
var _entry_tweens: Array[Tween] = []

const ROW_WIDTH: float = 480.0
const LEFT_MARGIN: float = -50.0


func show_options(options: Array[PlotOption], fonts: Dictionary) -> void:
	GameManager.font_tcm = fonts.get("tcm", null)
	GameManager.font_zh_body = fonts.get("zh_body", null)
	GameManager.font_en_body = fonts.get("en_body", null)
	_focused_idx = 0
	_option_count = options.size()
	_is_open = true
	mouse_filter = MOUSE_FILTER_STOP

	# 清除旧内容
	_kill_anim()
	for c in get_children():
		c.queue_free()
	_rows.clear()

	# 半透明黑色全屏遮罩
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)

	# 选项容器 — 左对齐
	var vbox := VBoxContainer.new()
	vbox.name = "ChoicesVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	# 垂直居中，水平左对齐
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	vbox.position = Vector2(LEFT_MARGIN, vp_size.y / 2.0 - OptionRow.ROW_HEIGHT * _option_count / 2.0)
	add_child(vbox)

	var is_zh: bool = GameManager.is_locale("zh")

	for i: int in range(_option_count):
		var opt: PlotOption = options[i]
		var text: String
		if is_zh:
			text = opt.ZH
		elif not opt.EN.is_empty():
			text = opt.EN
		else:
			text = tr(opt.ZH)
		var row: Control = _make_row(i, text)
		vbox.add_child(row)
		_rows.append(row)

	visible = true
	_animate_enter()


func hide_options() -> void:
	_is_open = false
	# 立即将鼠标过滤设为 IGNORE，防止淡出期间拦截点击事件
	mouse_filter = MOUSE_FILTER_IGNORE
	_kill_anim()

	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_anim_tween.tween_callback(_on_close_done)


func _on_close_done() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false


# ═══════════════════════════════════════════════════════════════
# 入场动画（对齐 TabMenu）
# ═══════════════════════════════════════════════════════════════

func _animate_enter() -> void:
	_kill_anim()

	modulate.a = 0.0
	_entry_tweens.clear()

	# 整体淡入
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.3)

	# 各行逐级淡入
	for i: int in range(_rows.size()):
		var row: Control = _rows[i]
		row.modulate.a = 0.0
		var st := create_tween()
		st.tween_interval(0.15 + i * 0.05)
		st.tween_property(row, "modulate:a", 1.0, 0.2)
		_entry_tweens.append(st)

	# 所有行淡入完成后应用焦点
	var focus_tween := create_tween()
	focus_tween.tween_interval(0.15 + _rows.size() * 0.05 + 0.15)
	focus_tween.tween_callback(_update_focus)
	_entry_tweens.append(focus_tween)


# ═══════════════════════════════════════════════════════════════
# 行构建（对齐 TabMenu 样式）
# ═══════════════════════════════════════════════════════════════

func _make_row(idx: int, text: String) -> OptionRow:
	var row := OptionRow.new()
	@warning_ignore("static_called_on_instance")
	var font: Font = GameManager.select_font(text, GameManager.font_zh_body, GameManager.font_en_body)
	# 单标签形态（VN 选项反例）：标题槽置空即跳过，文本走副标签槽 + 右侧 24 内缩
	row.setup(idx, "", text, null, font, ROW_WIDTH, 24.0)
	row.hovered.connect(_on_hover)
	row.activated.connect(_on_activated)
	return row


# ═══════════════════════════════════════════════════════════════
# 焦点动画（对齐 TabMenu）
# ═══════════════════════════════════════════════════════════════

func _update_focus() -> void:
	for i: int in range(_rows.size()):
		# 反例形态覆写：聚焦右移 +30 / 静止 0、不调暗、未聚焦白 0.85 / 聚焦纯黑
		_rows[i].apply_focus_state(i == _focused_idx, 30.0, 0.0, 1.0, Color(1, 1, 1, 0.85), Color.BLACK)


# ═══════════════════════════════════════════════════════════════
# 交互
# ═══════════════════════════════════════════════════════════════

func _on_hover(idx: int) -> void:
	if _focused_idx == idx: return
	_focused_idx = idx
	_update_focus()
	AudioManager.play_click()


func _on_activated(idx: int) -> void:
	AudioManager.play_click()
	choice_selected.emit(idx)


func _input(event: InputEvent) -> void:
	if not _is_open or not event.is_pressed():
		return

	if event.is_action_pressed("ui_up"):
		_focused_idx = (_focused_idx - 1 + _option_count) % _option_count
		_update_focus()
		AudioManager.play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_focused_idx = (_focused_idx + 1) % _option_count
		_update_focus()
		AudioManager.play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		AudioManager.play_click()
		choice_selected.emit(_focused_idx)
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════

func _kill_anim() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null
	for tw: Tween in _entry_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_entry_tweens.clear()
