## ChoicesMenu : Control
## 选择覆盖层 — 当剧情到达选择节点时显示。
##   键盘 ↑↓ 导航，Enter 确认，鼠标点击选择。
##   样式与动画对齐 TabMenu，选项卡左对齐，文字右对齐。
class_name ChoicesMenu
extends Control

signal choice_selected(index: int)

var _focused_idx: int = 0
var _option_count: int = 0
var _rows: Array[Control] = []
var _is_open: bool = false


var _anim_tween: Tween = null
var _entry_tweens: Array[Tween] = []

const ROW_HEIGHT: float = 51.0
const ROW_WIDTH: float = 480.0
const FOCUS_SWEEP_DUR: float = 0.25
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
	vbox.position = Vector2(LEFT_MARGIN, vp_size.y / 2.0 - ROW_HEIGHT * _option_count / 2.0)
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

func _make_row(idx: int, text: String) -> Control:
	var row := Control.new()
	row.name = "Choice_" + str(idx)
	row.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	row.mouse_filter = MOUSE_FILTER_STOP

	# 白色扫入背景
	var sweep := ColorRect.new()
	sweep.name = "Sweep"
	sweep.color = Color.WHITE
	sweep.size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	sweep.scale.x = 0.0
	sweep.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(sweep)

	# 内容行 — 右对齐，文字靠右
	var hb := HBoxContainer.new()
	hb.size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(hb)

	# 左侧间隔
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(16, 0)
	sp.mouse_filter = MOUSE_FILTER_IGNORE
	hb.add_child(sp)

	# 选项文本 — 右对齐
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	@warning_ignore("static_called_on_instance")
	lbl.add_theme_font_override("font", GameManager.select_font(text, GameManager.font_zh_body, GameManager.font_en_body))
	lbl.mouse_filter = MOUSE_FILTER_IGNORE
	hb.add_child(lbl)

	# 右侧间隔
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(24, 0)
	sp2.mouse_filter = MOUSE_FILTER_IGNORE
	hb.add_child(sp2)

	row.mouse_entered.connect(_on_hover.bind(idx))
	row.gui_input.connect(_on_click.bind(idx))
	row.set_meta("sweep", sweep)
	row.set_meta("lbl", lbl)
	return row


# ═══════════════════════════════════════════════════════════════
# 焦点动画（对齐 TabMenu）
# ═══════════════════════════════════════════════════════════════

func _update_focus() -> void:
	for i: int in range(_rows.size()):
		var row: Control = _rows[i]
		var on: bool = i == _focused_idx
		var sweep: ColorRect = row.get_meta("sweep")
		var lbl: Label = row.get_meta("lbl")

		var tw := create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(sweep, "scale:x", 1.0 if on else 0.0, FOCUS_SWEEP_DUR)
		tw.tween_property(row, "position:x", 30.0 if on else 0.0, FOCUS_SWEEP_DUR)

		lbl.add_theme_color_override("font_color", Color.BLACK if on else Color(1, 1, 1, 0.85))


# ═══════════════════════════════════════════════════════════════
# 交互
# ═══════════════════════════════════════════════════════════════

func _on_hover(idx: int) -> void:
	if _focused_idx == idx: return
	_focused_idx = idx
	_update_focus()
	AudioManager.play_click()


func _on_click(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
