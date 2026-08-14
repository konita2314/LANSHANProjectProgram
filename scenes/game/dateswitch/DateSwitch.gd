## DateSwitch : Control
## 游戏内日期切换器 — F9 调试工具。
## 垂直滚轮选择日期（1–31），月份通过左右键切换。
class_name DateSwitch
extends Control

signal back_requested()

const ITEM_SPACING: float = 160.0
const SCROLL_SPEED: float = 8.0
const MAX_DAYS: int = 31
const MONTH_NAMES: Array[String] = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
# 2022 年 8-11 月实际天数（Calendar 支持范围）
# 基础每月天数（二月动态按闰年计算）
const MONTH_DAYS_BASE: Array[int] = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# Calendar 场景约束的月份范围
const CALENDAR_MONTH_MIN: int = 8
const CALENDAR_MONTH_MAX: int = 11

# 年份范围（支线故事 1912-2022）
const YEAR_MIN: int = 1900
const YEAR_MAX: int = 2100


## 当前月份实际天数（含闰年二月）。
func _days_in_month() -> int:
	if _month == 2:
		if _year % 400 == 0 or (_year % 4 == 0 and _year % 100 != 0):
			return 29
		return 28
	return MONTH_DAYS_BASE[_month] if _month < MONTH_DAYS_BASE.size() else MAX_DAYS


## 规范化年份：两位自动展开为 2000+（22→2022）；>=100 原样保留。
static func _normalize_year(y: int) -> int:
	if y <= 0:
		return 2022  # 默认年份
	if y < 100:
		return 2000 + y
	return y

var _disabled: bool = false
var _is_visible: bool = false
var _day: int = 1
var _month: int = 9
var _year: int = 2022
var _current_scroll: float = 1.0
var _side_mode: bool = false
var _var_prefix: String = "game_"
var _target_scroll: float = 1.0
var _active_labels: Dictionary[int, Label] = {}
var _last_int_scroll: int = 1

# 自动关闭计时器 — 入场动画完成后倒计时 1 秒，期间按键 2 倍速
var _auto_close_timer: float = 0.0
var _auto_close_active: bool = false
var _speed_up: bool = false
var _anim_busy: bool = false

@onready var _scroll_area: Control = $ScrollArea
@onready var _month_label: Label = $MonthLabel
@onready var _indicator_line: ColorRect = $IndicatorLine

var _year_label: Label = null


func _ready() -> void:
	_read_global_date()
	_current_scroll = float(_day)
	_target_scroll = float(_day)
	_last_int_scroll = _day
	_update_month_label()
	_build_year_label()
	_apply_fonts()
	_hide_immediate()


func _hide_immediate() -> void:
	visible = false
	_is_visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_panel() -> void:
	if _anim_busy:
		return
	_anim_busy = true
	_play_click()
	_is_visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	_read_global_date()
	set_day(_day)
	_current_scroll = float(_day)
	_last_int_scroll = _day
	_update_month_label()

	# IndicatorLine sweep — 与 TabMenu 选项完全一致（纯白 + 左展开 + CUBIC 0.25s）
	_indicator_line.color = Color.WHITE
	_indicator_line.pivot_offset = Vector2.ZERO
	_indicator_line.scale.x = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_indicator_line, "scale:x", 1.0, 0.25)

	# 从左侧滑入（tween callback 链，无 await）
	var vp_w: float = get_viewport().get_visible_rect().size.x
	offset_left = -vp_w
	offset_right = -vp_w
	visible = true
	AudioManager.set_menu_mode(true)
	var st := create_tween().set_parallel(true)
	st.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	st.tween_property(self, "offset_left", 0.0, 0.45)
	st.tween_property(self, "offset_right", 0.0, 0.45)
	st.chain().tween_callback(_on_slide_in_done)


func _on_slide_in_done() -> void:
	AudioManager.set_menu_mode(false)
	_start_auto_close()


func _start_auto_close() -> void:
	_auto_close_active = true
	_auto_close_timer = 1.5  # 含 SceneManager 滑入 0.45s，剩余 ~1s 供查看
	_speed_up = false


func _hide_panel() -> void:
	if _anim_busy:
		return
	_anim_busy = true
	_auto_close_active = false
	_play_click()
	_write_global_date()
	_slide_out_hide()


func _slide_out_hide() -> void:
	AudioManager.set_menu_mode(true)
	var vp_w: float = get_viewport().get_visible_rect().size.x
	var st := create_tween().set_parallel(true)
	st.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	st.tween_property(self, "offset_left", -vp_w, 0.35)
	st.tween_property(self, "offset_right", -vp_w, 0.35)
	st.chain().tween_callback(_on_slide_out_done)


func _on_slide_out_done() -> void:
	AudioManager.set_menu_mode(false)
	_hide_immediate()
	_anim_busy = false
	back_requested.emit()


func _read_global_date() -> void:
	var ctx: ScriptContext = GameManager.script_context
	if ctx:
		# 读取模式
		_side_mode = int(ctx.get_var("__temp_st_mode")) == 1
		# 主线：game_* → 存档作用域；支线：__temp_side_* → 会话临时，不入存档
		_var_prefix = "__temp_side_" if _side_mode else "game_"

		var y: int = _normalize_year(int(ctx.get_var(_var_prefix + "year")))
		if y >= YEAR_MIN and y <= YEAR_MAX:
			_year = y
		var m: int = int(ctx.get_var(_var_prefix + "month"))
		var d: int = int(ctx.get_var(_var_prefix + "day"))
		var month_min: int = 1 if _side_mode else CALENDAR_MONTH_MIN
		var month_max: int = 12 if _side_mode else CALENDAR_MONTH_MAX
		if m >= month_min and m <= month_max:
			_month = m
		if d >= 1 and d <= MAX_DAYS:
			_day = d
		_clamp_day_to_month()
	if _year_label:
		_year_label.text = str(_year)


func _write_global_date() -> void:
	var ctx: ScriptContext = GameManager.script_context
	if ctx:
		var max_d: int = _days_in_month()
		var normalized_day: int = ((_day - 1) % max_d + max_d) % max_d + 1
		ctx.apply_expression(_var_prefix + "year = " + str(_year), false)
		ctx.apply_expression(_var_prefix + "month = " + str(_month), false)
		ctx.apply_expression(_var_prefix + "day = " + str(normalized_day), false)


func _build_year_label() -> void:
	# ── 年份外框，作为 IndicatorLine 子节点，位于其内部 ──
	const BOX_W: float = 100.0
	const BOX_H: float = 44.0
	# IndicatorLine 实际高 48px (offset_top=-22, offset_bottom=26)，框居中
	const LINE_H: float = 48.0
	const BOX_Y: float = (LINE_H - BOX_H) / 2.0  # = 2
	const BOX_X: float = 18.0                     # IndicatorLine 内部，距左边缘 18px

	var box := ColorRect.new()
	box.name = "YearBox"
	box.color = Color.WHITE
	box.position = Vector2(BOX_X, BOX_Y)
	box.size = Vector2(BOX_W, BOX_H)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator_line.add_child(box)

	_year_label = Label.new()
	_year_label.name = "YearLabel"
	_year_label.position = Vector2(14.0, 0.0)
	_year_label.size = Vector2(BOX_W - 20.0, BOX_H)
	_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_year_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_year_label.add_theme_color_override("font_color", Color.BLACK)
	_year_label.add_theme_font_size_override("font_size", 28)
	_year_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_year_label.text = str(_year)
	box.add_child(_year_label)


func _update_month_label() -> void:
	_month_label.text = MONTH_NAMES[_month] + "."


func _apply_fonts() -> void:
	if GameManager.font_tcm:
		_month_label.add_theme_font_override("font", GameManager.font_tcm)
		_year_label.add_theme_font_override("font", GameManager.font_tcm)


func _apply_label_font(label: Label) -> void:
	if GameManager.font_tcm:
		label.add_theme_font_override("font", GameManager.font_tcm)


func set_day(day: int) -> void:
	_day = day
	_target_scroll = float(day)


## 将日期钳制到当前月份的实际天数范围内。
func _clamp_day_to_month() -> void:
	var max_d: int = _days_in_month()
	var norm: int = ((_day - 1) % max_d + max_d) % max_d + 1
	if norm != _day:
		_day = norm
		_target_scroll = float(_day)
		_current_scroll = float(_day)
		_last_int_scroll = _day


## 切换月份时钳制到 Calendar 有效范围 + 钳制日期。
func _set_month(m: int) -> void:
	var mn: int = 1 if _side_mode else CALENDAR_MONTH_MIN
	var mx: int = 12 if _side_mode else CALENDAR_MONTH_MAX
	_month = clampi(m, mn, mx)
	_update_month_label()
	_clamp_day_to_month()


var _year_anim_tween: Tween = null

## 切换年份，钳制到有效范围，闰年二月自动修正。
func _set_year(y: int) -> void:
	var clamped: int = clampi(y, YEAR_MIN, YEAR_MAX)
	if clamped == _year:
		return
	var old_year: int = _year
	_year = clamped
	_clamp_day_to_month()  # 闰年二月可能从 29→28

	if _year_label and _is_visible:
		_animate_year_flip(old_year, clamped)

## 年份倒带动画：旧数字下沉淡出 → 更新文本 → 新数字从上滑入
func _animate_year_flip(from_year: int, to_year: int) -> void:
	if _year_anim_tween and _year_anim_tween.is_valid():
		_year_anim_tween.kill()

	var label := _year_label
	var rest_y: float = label.position.y

	# 阶段 1：下沉 + 淡出（方向由年份增减决定：减→向下，增→向上）
	var dir: float = -1.0 if to_year < from_year else 1.0
	_year_anim_tween = create_tween().set_parallel(true)
	_year_anim_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	_year_anim_tween.tween_property(label, "position:y", rest_y + dir * 18.0, 0.15)
	_year_anim_tween.tween_property(label, "modulate:a", 0.0, 0.12)

	# 阶段 2：更新文本 → 从反向滑入
	_year_anim_tween.chain().tween_callback(_on_year_flip_mid.bind(to_year, rest_y, dir))

func _on_year_flip_mid(new_year: int, rest_y: float, dir: float) -> void:
	if not _year_label:
		return
	_year_label.text = str(new_year)
	_year_label.position.y = rest_y - dir * 18.0

	# 阶段 3：滑入 + 淡入
	_year_anim_tween = create_tween().set_parallel(true)
	_year_anim_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_year_anim_tween.tween_property(_year_label, "position:y", rest_y, 0.18)
	_year_anim_tween.tween_property(_year_label, "modulate:a", 1.0, 0.18)


func _process(delta: float) -> void:
	# ── 日期滚轮 ──
	_current_scroll = lerpf(_current_scroll, _target_scroll, SCROLL_SPEED * delta)
	var cur_int: int = int(roundf(_current_scroll))
	if cur_int != _last_int_scroll:
		_last_int_scroll = cur_int
		if _is_visible:
			_play_click()

	var min_val: int = int(floorf(_current_scroll - 2.5))
	var max_val: int = int(ceilf(_current_scroll + 2.5))

	var keys_to_remove: Array[int] = []
	for key: int in _active_labels.keys():
		if key < min_val or key > max_val:
			_active_labels[key].queue_free()
			keys_to_remove.append(key)
	for key: int in keys_to_remove:
		_active_labels.erase(key)

	var center_y: float = _scroll_area.size.y / 2.0
	var center_x: float = _scroll_area.size.x / 2.0

	for i: int in range(min_val, max_val + 1):
		var day_val: int = ((i - 1) % MAX_DAYS + MAX_DAYS) % MAX_DAYS + 1
		var label: Label
		if _active_labels.has(i):
			label = _active_labels[i]
		else:
			label = Label.new()
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_scroll_area.add_child(label)
			_active_labels[i] = label
			label.text = str(day_val)
			label.add_theme_font_size_override("font_size", 120)
			_apply_label_font(label)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var distance: float = i - _current_scroll
		var y_pos: float = distance * ITEM_SPACING

		var l_size: Vector2 = label.get_minimum_size()
		label.size = l_size
		label.pivot_offset = l_size / 2.0
		label.position = Vector2(center_x - l_size.x / 2.0, center_y + y_pos - l_size.y / 2.0)

		var abs_dist: float = absf(distance)
		var weight: float = clampf(abs_dist, 0.0, 1.5) / 1.5
		label.modulate = Color.WHITE.lerp(Color(0.25, 0.25, 0.25, 1.0), clampf(weight, 0.0, 1.0))
		var scale_val: float = lerpf(1.0, 0.65, clampf(weight, 0.0, 1.0))
		label.scale = Vector2(scale_val, scale_val)

	# ── 自动关闭倒计时 ──
	if _auto_close_active:
		var rate: float = 2.0 if _speed_up else 1.0
		_auto_close_timer -= delta * rate
		if _auto_close_timer <= 0.0:
			_auto_close_active = false
			_slide_out_hide()


func _input(event: InputEvent) -> void:
	if _disabled or not _is_visible or _anim_busy or not event.is_pressed():
		return

	# 劫持所有输入 — 禁止穿透到下层场景（VN 等）
	get_viewport().set_input_as_handled()

	# 自动关闭倒计时期间，任意键触发 2 倍速
	if _auto_close_active:
		_speed_up = true
		return

	if event.is_action_pressed("ui_up"):
		set_day(_day - 1)
	elif event.is_action_pressed("ui_down"):
		set_day(_day + 1)
	elif event.is_action_pressed("ui_left"):
		if Input.is_key_pressed(KEY_SHIFT):
			_set_year(_year - 1)
		else:
			_set_month(_month - 1)
	elif event.is_action_pressed("ui_right"):
		if Input.is_key_pressed(KEY_SHIFT):
			_set_year(_year + 1)
		else:
			_set_month(_month + 1)
	elif event.is_action_pressed("ui_accept"):
		_write_global_date()
		_play_click()
	elif event.is_action_pressed("ui_cancel"):
		_hide_panel()


func _play_click() -> void:
	AudioManager.play_click()


func _on_enter() -> void:
	_disabled = false
	# 重置为默认值，防止上次会话的残留值污染本次读取
	# （当 game_month 不在 DateSwitch 有效范围 [8,11] 时，_read_global_date 不会覆盖 _month）
	_month = 9
	_day = 1
	_year = 2022
	_read_global_date()
	set_day(_day)
	_current_scroll = float(_day)
	_last_int_scroll = _day
	_update_month_label()

	# 在 visible 之前设初始态，防止 IndicatorLine 闪现
	_indicator_line.color = Color.WHITE
	_indicator_line.pivot_offset = Vector2.ZERO
	_indicator_line.scale.x = 0.0

	visible = true
	_is_visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	# IndicatorLine sweep — 与 TabMenu 选项完全一致（纯白 + 左展开 + CUBIC 0.25s）
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_indicator_line, "scale:x", 1.0, 0.25)
	_anim_busy = true
	_check_target_date()


## 检测 ScriptContext 中的 _st_target_*，若与当前不同则滚动过去。
func _check_target_date() -> void:
	var ctx: ScriptContext = GameManager.script_context
	if not ctx:
		_start_auto_close()
		return
	var ty: int = _normalize_year(int(ctx.get_var("__temp_st_target_year")))
	var tm: int = int(ctx.get_var("__temp_st_target_month"))
	var td: int = int(ctx.get_var("__temp_st_target_day"))
	if tm <= 0 or td <= 0 or (ty == _year and tm == _month and td == _day):
		_start_auto_close()
		return
	# 清除临时变量
	ctx.apply_expression("__temp_st_target_year = 0", false)
	ctx.apply_expression("__temp_st_target_month = 0", false)
	ctx.apply_expression("__temp_st_target_day = 0", false)
	# 延迟一瞬再滚动，让玩家看到初始日期
	var delay_tw := create_tween()
	delay_tw.tween_interval(0.5)
	delay_tw.tween_callback(_on_target_date_jump.bind(ty, tm, td))


## 目标日期跳转回调 — 替换原有 lambda，符合项目规范
func _on_target_date_jump(ty: int, tm: int, td: int) -> void:
	_set_year(ty)
	_set_month(tm)
	set_day(td)
	_write_global_date()
	var settle := create_tween()
	settle.tween_interval(1.0)
	settle.tween_callback(_start_auto_close)


func _on_exit() -> void:
	_disabled = true


func set_disabled(val: bool) -> void:
	_disabled = val
