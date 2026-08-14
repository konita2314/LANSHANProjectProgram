## CalendarScene : Control
## 游戏内日历系统 — 2022年8月至11月战术日程面板。
## 静态 UI 节点在 CalendarScene.tscn 中；动态内容（日期格、字体、动画）在代码构建。
extends Control

signal back_requested()

const MONTHS_EN: Array[String] = ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const MONTH_MIN: int = 8
const MONTH_MAX: int = 11
const YEAR: int = 2022
const CELL_COUNT: int = 42

# ---------------------------------------------------------------------------
# 状态
# ---------------------------------------------------------------------------
var _month: int = 9
var _selected: String = ""
var _focus_idx: int = -1
var _cell_nodes_a: Array[Control] = []
var _cell_nodes_b: Array[Control] = []
var _current_cells: Array[Control] = []
var _using_grid_a: bool = true
var _is_animating: bool = false
@warning_ignore("unused_private_class_variable")
var _info_panel_shown: bool = false
var _panel_tween: Tween = null
var _grid_tween: Tween = null
var _label_tween: Tween = null
var _is_first_enter: bool = true
var _can_go_back: bool = true

# ---------------------------------------------------------------------------
# @onready 节点引用
# ---------------------------------------------------------------------------
@onready var _month_lbl: Label = $MonthLabel
@onready var _nav_prev: Button = $NavPrev
@onready var _nav_next: Button = $NavNext
@warning_ignore("unused_private_class_variable")
@onready var _grid_area: Control = $GridArea
@onready var _weekday_row: HBoxContainer = $GridArea/WeekdayRow
@onready var _grid_a: GridContainer = $GridArea/DayGrid
@onready var _info_panel: Control = $InfoPanel
@onready var _info_name: Label = $InfoPanel/NameLabel
@onready var _info_desc: Label = $InfoPanel/DescLabel
@onready var _info_border: ColorRect = $InfoPanel/BorderBot
var _grid_clip: Control = null
var _grid_b: GridContainer = null
var _back_bar := BackBar.new()


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:
	_init_state()
	_setup_grid_clip()
	_apply_fonts()
	_connect_signals()
	_build_static_runtime_ui()
	_refresh_view()
	_setup_backbar()


func _init_state() -> void:
	_selected = "2022-09-15"


func _setup_grid_clip() -> void:
	var parent := _grid_a.get_parent()

	_grid_clip = Control.new()
	_grid_clip.name = "GridClip"
	_grid_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_grid_clip)

	_grid_a.reparent(_grid_clip)
	_grid_a.name = "DayGridA"

	_grid_b = GridContainer.new()
	_grid_b.name = "DayGridB"
	_grid_b.columns = 7
	_grid_b.position = Vector2(0, _grid_a.position.y)
	_grid_b.add_theme_constant_override("h_separation", 6)
	_grid_b.add_theme_constant_override("v_separation", 6)
	_grid_b.visible = false
	_grid_clip.add_child(_grid_b)


func _connect_signals() -> void:
	_nav_prev.pressed.connect(_on_nav.bind(-1))
	_nav_next.pressed.connect(_on_nav.bind(1))


func _build_static_runtime_ui() -> void:
	_build_weekday_row()
	_create_cell_pool(_grid_a, _cell_nodes_a)
	_create_cell_pool(_grid_b, _cell_nodes_b)
	_current_cells = _cell_nodes_a


func _refresh_view() -> void:
	_update_month_label()
	_refresh_all_cells()
	_find_focus_for_selected()
	_refresh_detail()


func _setup_backbar() -> void:
	_back_bar = BackBar.attach(self, _request_back)


func _on_enter() -> void:
	_apply_global_date()
	if _is_first_enter:
		_is_first_enter = false
		_animate_first_entrance()
	else:
		_update_focus_two_cells(-1, _focus_idx)
		_show_info_panel()


## 从存档作用域读取 game_month / game_day，聚焦到指定日期。
func _apply_global_date() -> void:
	var ctx: ScriptContext = GameManager.script_context
	if not ctx:
		return
	var m: int = int(ctx.get_var("game_month"))
	var d: int = int(ctx.get_var("game_day"))
	if m < MONTH_MIN or m > MONTH_MAX or d < 1 or d > 31:
		return
	_month = m
	_selected = "%d-%02d-%02d" % [YEAR, m, d]
	_refresh_view()


func _on_exit() -> void:
	_hide_info_panel()


## 控制场景是否可通过 ESC / BackBar 返回上一级。
func set_can_go_back(can: bool) -> void:
	_can_go_back = can
	_back_bar.visible = can


func set_disabled(_v: bool) -> void:
	pass


# ===================================================================
# 字体
# ===================================================================

func _apply_fonts() -> void:
	if GameManager.font_tcm:
		_month_lbl.add_theme_font_override("font", GameManager.font_tcm)
		_nav_prev.add_theme_font_override("font", GameManager.font_tcm)
		_nav_next.add_theme_font_override("font", GameManager.font_tcm)
		_info_name.add_theme_font_override("font", GameManager.font_tcm)

		if GameManager.font_en_body:
			_info_desc.add_theme_font_override("font", GameManager.font_en_body)

	for child: Control in _weekday_row.get_children():
		if child.get_child_count() >= 2:
			var lbl: Label = child.get_child(1) as Label
			if lbl and GameManager.font_tcm:
				lbl.add_theme_font_override("font", GameManager.font_tcm)
				lbl.add_theme_font_size_override("font_size", 22)


# ===================================================================
# 顶栏 — 月份标签 + 导航
# ===================================================================

func _on_nav(dir: int) -> void:
	if _is_animating:
		return
	AudioManager.play_click()
	var m := _month + dir
	if m < MONTH_MIN or m > MONTH_MAX:
		return
	_month = m
	_animate_month_label(dir)
	_animate_month_switch(dir)


func _update_month_label() -> void:
	var ms := "0%d" % _month if _month < 10 else str(_month)
	_month_lbl.text = "%d.%s  %s" % [YEAR, ms, MONTHS_EN[_month]]


func _animate_month_label(dir: int) -> void:
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()
	_month_lbl.modulate.a = 1.0

	var slide_out: float = -dir * 30.0
	_label_tween = create_tween().set_parallel(true)
	_label_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_label_tween.tween_property(_month_lbl, "position:y", _month_lbl.position.y + slide_out, 0.15)
	_label_tween.tween_property(_month_lbl, "modulate:a", 0.0, 0.12)
	await _label_tween.finished

	_update_month_label()
	_month_lbl.position.y -= slide_out * 2.0

	var t2 := create_tween().set_parallel(true)
	t2.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t2.tween_property(_month_lbl, "position:y", _month_lbl.position.y + slide_out, 0.20)
	t2.tween_property(_month_lbl, "modulate:a", 1.0, 0.20)
	_label_tween = t2


# ===================================================================
# 星期行
# ===================================================================

func _build_weekday_row() -> void:
	const WEEKDAYS: Array[String] = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

	for i: int in 7:
		var sun: bool = i == 0

		var c := Control.new()
		c.custom_minimum_size = Vector2(94, 36)
		_weekday_row.add_child(c)

		var bg := ColorRect.new()
		bg.set_anchors_preset(PRESET_FULL_RECT)
		bg.color = Color(1, 0.102, 0.102, 0.10) if sun else Color(0.039, 0.039, 0.039)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(bg)

		var lbl := Label.new()
		lbl.text = WEEKDAYS[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(PRESET_FULL_RECT)
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(1, 0.102, 0.102) if sun else Color.WHITE)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(lbl)


# ===================================================================
# Cell 池 — 42 格复用，两个 Grid 各一份
# ===================================================================

func _create_cell_pool(grid: GridContainer, into: Array[Control]) -> void:
	for _i: int in CELL_COUNT:
		var cell := _create_cell()
		grid.add_child(cell)
		into.append(cell)


func _create_cell() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(94, 80)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(_on_cell_click.bind(c))

	var content := Control.new()
	content.name = "Content"
	content.set_anchors_preset(PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(content)

	var sweep := ColorRect.new()
	sweep.name = "Sweep"
	sweep.color = Color(1, 1, 1, 0.15)
	sweep.size.x = 0.0
	sweep.custom_minimum_size.y = 80
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(sweep)

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bg)

	var dn := Label.new()
	dn.name = "Day"
	dn.position = Vector2(8, 6)
	dn.add_theme_font_size_override("font_size", 26)
	dn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_tcm:
		dn.add_theme_font_override("font", GameManager.font_tcm)
	content.add_child(dn)

	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.color = Color(1, 0.102, 0.102, 0.8)
	dot.size = Vector2(6, 6)
	dot.position = Vector2(80, 10)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.visible = false
	content.add_child(dot)

	var dc := Label.new()
	dc.name = "Code"
	dc.position = Vector2(8, 64)
	dc.add_theme_font_size_override("font_size", 9)
	dc.add_theme_color_override("font_color", Color(0.44, 0.44, 0.44))
	dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_tcm:
		dc.add_theme_font_override("font", GameManager.font_tcm)
	content.add_child(dc)

	c.set_meta("sweep", sweep)
	c.set_meta("content", content)
	return c


# ===================================================================
# Cell 数据更新 — 含字体颜色（选中/sweep 动画不覆盖）
# ===================================================================

func _apply_cell_data(cell: Control, cd: Dictionary) -> void:
	var out: bool = not _is_valid(cd.date)
	var evt: bool = cd.entry.get("event", false)
	var cur: bool = cd.cur
	var sun: bool = cd.sun

	# 重置 sweep 高亮，防止跨月份切换时出现残留选中态
	_kill_cell_tween(cell)
	var sweep_rect: ColorRect = cell.get_meta("sweep")
	if sweep_rect:
		sweep_rect.size.x = 0.0

	var content: Control = cell.get_meta("content")
	var bg: ColorRect = content.get_node_or_null("Bg") as ColorRect
	if bg:
		var bgc: Color
		if out:         bgc = Color(0.02, 0.02, 0.02)
		elif not cur:   bgc = Color(0.031, 0.031, 0.031)
		else:           bgc = Color(0.039, 0.039, 0.039)
		bg.color = bgc

	var dn: Label = content.get_node_or_null("Day") as Label
	if dn:
		dn.text = "0%d" % cd.day if cd.day < 10 else str(cd.day)
		# 字体颜色只需在此设置一次，sweep 动画不再覆盖
		if out:
			dn.add_theme_color_override("font_color", Color(0.38, 0.38, 0.38))
		elif sun:
			dn.add_theme_color_override("font_color", Color(1, 0.102, 0.102))
		else:
			dn.add_theme_color_override("font_color", Color.WHITE)

	var dot: ColorRect = content.get_node_or_null("Dot") as ColorRect
	if dot:
		dot.visible = evt and not out

	var dc: Label = content.get_node_or_null("Code") as Label
	if dc:
		dc.text = "%02d.%02d" % [cd.month, cd.day]

	cell.set_meta("date", cd.date)
	cell.set_meta("out", out)
	cell.set_meta("sun", sun)
	cell.set_meta("cur", cur)
	cell.visible = true

	if out:       cell.modulate.a = 0.35
	elif not cur: cell.modulate.a = 0.3
	else:         cell.modulate.a = 1.0


func _hide_cell(cell: Control) -> void:
	cell.visible = false


func _refresh_all_cells() -> void:
	var data: Array = _gen_grid()
	for i: int in CELL_COUNT:
		if i < data.size():
			_apply_cell_data(_current_cells[i], data[i])
		else:
			_hide_cell(_current_cells[i])


# ===================================================================
# Focus sweep 动画 — 仅 sweep size.x，不改字体颜色
# ===================================================================

func _update_focus_two_cells(old_idx: int, new_idx: int) -> void:
	if old_idx == new_idx:
		return
	if old_idx >= 0 and old_idx < CELL_COUNT:
		_animate_cell_deselect(_current_cells[old_idx])
	if new_idx >= 0 and new_idx < CELL_COUNT:
		_animate_cell_select(_current_cells[new_idx])


func _animate_cell_select(cell: Control) -> void:
	if not cell.visible:
		return

	_kill_cell_tween(cell)
	var sweep: ColorRect = cell.get_meta("sweep")
	sweep.color.a = 0.35
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(sweep, "size:x", 94.0, 0.20)
	tw.tween_property(sweep, "color:a", 0.15, 0.30)
	cell.set_meta("sweep_tween", tw)


func _animate_cell_deselect(cell: Control) -> void:
	if not cell.visible:
		return

	_kill_cell_tween(cell)
	var sweep: ColorRect = cell.get_meta("sweep")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(sweep, "size:x", 0.0, 0.20)
	tw.tween_property(sweep, "color:a", 0.0, 0.20)
	cell.set_meta("sweep_tween", tw)


func _kill_cell_tween(cell: Control) -> void:
	if not cell.has_meta("sweep_tween"):
		return
	var old: Tween = cell.get_meta("sweep_tween")
	if old and old.is_valid():
		old.kill()



func _find_focus_for_selected() -> void:
	var data: Array = _gen_grid()
	var old: int = _focus_idx
	_focus_idx = -1
	for i: int in data.size():
		if data[i].date == _selected:
			_focus_idx = i
			break
	_update_focus_two_cells(old, _focus_idx)


# ===================================================================
# 键盘 / 鼠标导航
# ===================================================================

## 从 from_idx 沿 (dx, dy) 方向寻找下一个有效日期。
## 返回有效索引，或 -1（无有效目标）。
func _find_valid_in_direction(from_idx: int, dx: int, dy: int) -> int:
	var data: Array = _gen_grid()
	var count: int = data.size()
	if count == 0:
		return -1
	var total_rows: int = ceili(float(count) / 7.0)
	const MAX_ITER: int = 42

	var col: int = from_idx % 7
	@warning_ignore("integer_division")
	var row: int = from_idx / 7
	col += dx
	row += dy

	for _iter: int in MAX_ITER:
		if col < 0 or col >= 7 or row < 0 or row >= total_rows:
			return -1
		var idx: int = row * 7 + col
		if idx >= count:
			return -1
		if _is_valid(data[idx].date):
			return idx
		col += dx
		row += dy

	return -1


func _navigate_focus(dx: int, dy: int) -> void:
	if _focus_idx < 0:
		# 无焦点 → 选中当前月份第一个有效日期
		var data: Array = _gen_grid()
		for i: int in data.size():
			if _is_valid(data[i].date):
				_select_by_idx(i)
				return
		return

	var target: int = _find_valid_in_direction(_focus_idx, dx, dy)
	if target >= 0:
		_select_by_idx(target)


func _select_by_idx(idx: int) -> void:
	var data: Array = _gen_grid()
	if idx < 0 or idx >= data.size():
		return
	var ds: String = data[idx].date
	if not _is_valid(ds):
		return

	# 跨月导航 → 切换到目标月份
	var parts := ds.split("-")
	var clicked_month: int = parts[1].to_int()
	if clicked_month != _month and not _is_animating:
		_selected = ds
		_on_nav(1 if clicked_month > _month else -1)
		return

	var old_focus: int = _focus_idx
	_selected = ds
	_focus_idx = idx

	_update_focus_two_cells(old_focus, _focus_idx)
	_refresh_detail()



func _on_cell_click(event: InputEvent, cell: Control) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var ds: String = cell.get_meta("date", "")
	if ds.is_empty() or not _is_valid(ds):
		return
	var parts := ds.split("-")
	var clicked_month: int = parts[1].to_int()
	if clicked_month != _month and not _is_animating:
		_selected = ds
		_on_nav(1 if clicked_month > _month else -1)
		return
	for i: int in _current_cells.size():
		if _current_cells[i] == cell:
			AudioManager.play_click()
			_select_by_idx(i)
			break

# ===================================================================
# 输入 — ESC / 方向键 / WASD
# ===================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _can_go_back:
			_request_back()
		get_viewport().set_input_as_handled()
		return

	if not event.is_pressed():
		return

	if event.is_action_pressed("ui_up"):
		_navigate_focus(0, -1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_navigate_focus(0, 1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_navigate_focus(-1, 0); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_navigate_focus(1, 0); get_viewport().set_input_as_handled()

	# WASD 已通过 Godot 默认 Input Map 映射到 ui_* 动作，无需单独处理


# ===================================================================
# 月份切换 — 双 Grid 滑入滑出
# ===================================================================

func _other_grid() -> GridContainer:
	return _grid_b if _using_grid_a else _grid_a


func _other_cells() -> Array[Control]:
	return _cell_nodes_b if _using_grid_a else _cell_nodes_a


func _animate_month_switch(dir: int) -> void:
	if _is_animating:
		return
	_is_animating = true

	var next_grid: GridContainer = _other_grid()
	var next_cells: Array[Control] = _other_cells()
	var cur_grid: GridContainer = _grid_a if _using_grid_a else _grid_b

	var data: Array = _gen_grid()
	for i: int in CELL_COUNT:
		if i < data.size():
			_apply_cell_data(next_cells[i], data[i])
		else:
			_hide_cell(next_cells[i])

	var slide_in_from: float = dir * 80.0
	next_grid.position.x = slide_in_from
	next_grid.modulate.a = 0.0
	next_grid.visible = true

	if _grid_tween and _grid_tween.is_valid():
		_grid_tween.kill()

	_grid_tween = create_tween().set_parallel(true)
	_grid_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_grid_tween.tween_property(cur_grid, "position:x", -slide_in_from, 0.22)
	_grid_tween.tween_property(cur_grid, "modulate:a", 0.0, 0.18)
	_grid_tween.tween_property(next_grid, "position:x", 0.0, 0.22)
	_grid_tween.tween_property(next_grid, "modulate:a", 1.0, 0.22)
	await _grid_tween.finished

	cur_grid.visible = false
	cur_grid.position.x = 0.0
	cur_grid.modulate.a = 1.0

	_using_grid_a = not _using_grid_a
	_current_cells = next_cells
	_focus_idx = -1
	_find_focus_for_selected()
	_is_animating = false


# ===================================================================
# 首次入场 — 按行（6 Tween）错峰淡入
# ===================================================================

func _animate_first_entrance() -> void:
	var data: Array = _gen_grid()
	for i: int in CELL_COUNT:
		if i < data.size():
			var cell := _cell_nodes_a[i]
			_apply_cell_data(cell, data[i])
			cell.set_meta("target_alpha", cell.modulate.a)
			cell.modulate.a = 0.0
		else:
			_hide_cell(_cell_nodes_a[i])

	for row: int in 6:
		var t_row := create_tween()
		for col: int in 7:
			var i: int = row * 7 + col
			if i >= CELL_COUNT or i >= data.size():
				break
			var cell := _cell_nodes_a[i]
			var target: float = cell.get_meta("target_alpha", 1.0)
			t_row.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			t_row.tween_property(cell, "modulate:a", target, 0.15)
		t_row.tween_interval(row * 0.04)

	_find_focus_for_selected()

	var t_info := create_tween()
	t_info.tween_interval(0.10)
	t_info.tween_callback(_show_info_panel)


# ===================================================================
# 网格数据
# ===================================================================

func _gen_grid() -> Array:
	var r: Array = []
	var fd := _dow(_month, 1)
	var dim := _days_in(_month)

	if fd > 0:
		var pm := _month - 1 if _month > 1 else 12
		var pd := _days_in(pm)
		for i: int in range(fd - 1, -1, -1):
			r.append(_cell_data(pm, pd - i, false))

	for d: int in range(1, dim + 1):
		r.append(_cell_data(_month, d, true))

	var t := r.size()
	var n := (35 if t <= 35 else 42) - t
	if n > 0:
		var nm := _month + 1 if _month < 12 else 1
		for d: int in range(1, n + 1):
			r.append(_cell_data(nm, d, false))
	return r


func _cell_data(m: int, d: int, cur: bool) -> Dictionary:
	var ds := _fmt(YEAR, m, d)
	return {"day": d, "month": m, "date": ds, "cur": cur, "sun": _dow(m, d) == 0,
			"entry": CalendarData.get_entry(ds)}



# ===================================================================
# InfoPanel
# ===================================================================

func _show_info_panel() -> void:
	var vp_w: float = get_viewport().get_visible_rect().size.x

	_info_panel.offset_left = vp_w
	_info_panel.offset_right = vp_w
	_info_panel.modulate.a = 1.0
	_info_panel.visible = true

	_info_border.scale = Vector2(0.0, 1.0)
	var name_target_x: float = _info_name.position.x
	_info_name.position.x += 50.0
	_info_name.modulate.a = 0.0
	var desc_target_x: float = _info_desc.position.x
	_info_desc.position.x += 50.0
	_info_desc.modulate.a = 0.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(8, 6)
	sb.shadow_color = Color(1, 1, 1, 0.1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_info_name.add_theme_stylebox_override("normal", sb)

	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()

	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(_info_panel, "offset_left", 0.0, 0.35)
	_panel_tween.tween_property(_info_panel, "offset_right", 0.0, 0.35)

	var t_border := create_tween()
	t_border.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_border.tween_property(_info_border, "scale:x", 1.0, 0.5).set_delay(0.12)

	var t_name := create_tween().set_parallel(true)
	t_name.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_name.tween_property(_info_name, "position:x", name_target_x, 0.5).set_delay(0.20)
	t_name.tween_property(_info_name, "modulate:a", 1.0, 0.5).set_delay(0.20)

	var t_desc := create_tween().set_parallel(true)
	t_desc.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_desc.tween_property(_info_desc, "position:x", desc_target_x, 0.5).set_delay(0.1)
	t_desc.tween_property(_info_desc, "modulate:a", 1.0, 0.5).set_delay(0.1)


func _hide_info_panel() -> void:
	if not _info_panel.visible:
		return

	var vp_w: float = get_viewport().get_visible_rect().size.x
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()

	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_panel_tween.tween_property(_info_panel, "offset_left", vp_w, 0.3)
	_panel_tween.tween_property(_info_panel, "offset_right", vp_w, 0.3)
	_panel_tween.chain().tween_callback(_on_panel_hidden)


func _on_panel_hidden() -> void:
	_info_panel.visible = false


func _refresh_detail() -> void:
	_update_detail_text()


func _update_detail_text() -> void:
	var e := CalendarData.get_entry(_selected)
	var parts := _selected.split("-")
	var y: int = parts[0].to_int()
	var m: int = parts[1].to_int()
	var d: int = parts[2].to_int()
	var dn := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

	_info_name.text = "%d %s %02d  %s" % [y, MONTHS_EN[m], d, dn[_dow(m, d)]]
	@warning_ignore("static_called_on_instance")
	if GameManager.font_tcm:
		_info_name.add_theme_font_override("font", GameManager.font_tcm)

	var things: String = str(e.get("things", "")) if not e.is_empty() else ""
	var event_text: String = "〓 EVENT 〓" if e.get("event", false) else ""

	var desc_lines: String = ""
	if not event_text.is_empty():
		desc_lines += event_text + "\n"
	desc_lines += things
	_info_desc.text = desc_lines


# ===================================================================
# 工具
# ===================================================================

func _is_valid(ds: String) -> bool:
	return ds >= CalendarData.MIN_DATE_STR and ds <= CalendarData.MAX_DATE_STR


func _fmt(y: int, m: int, d: int) -> String:
	return "%d-%02d-%02d" % [y, m, d]


func _dow(month: int, day: int) -> int:
	var total := 0
	for mm: int in range(8, month):
		total += _days_in(mm)
	total += day - 28
	return total % 7


func _days_in(month: int) -> int:
	if month in [1, 3, 5, 7, 8, 10, 12]:
		return 31
	if month in [4, 6, 9, 11]:
		return 30
	return 28


# ===================================================================
# 返回
# ===================================================================

func _request_back() -> void:
	AudioManager.play_click()
	back_requested.emit()
