## SaveMenu : Control
## 游戏内存档覆盖层。与 LoadScene 相同的存档槽卡片设计。
extends Control

signal close_requested()
signal save_selected(slot_index: int)

var _slots: Array = []
var _focus_idx: int = 0
var _anim_tween: Tween = null


const SLOT_W: float = 540.0
const SLOT_H: float = 160.0
const COLS: int = 2
const GAP: float = 24.0

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title_label: Label = $TitleLabel
@onready var _slots_grid: GridContainer = $Scroll/SlotsGrid
@onready var _close_btn: Button = $CloseBtn
@onready var _scroll: ScrollContainer = $Scroll


func open(fonts: Dictionary, _hint: String = "") -> void:
	GameManager.font_tcm = fonts.get("tcm")
	GameManager.font_zh_body = fonts.get("zh_body")
	GameManager.font_zh_title = fonts.get("zh_title")
	GameManager.font_en_body = fonts.get("en_body")
	_focus_idx = 0
	_refresh()
	if _close_btn:
		_close_btn.visible = false
		if GameManager.font_tcm: _close_btn.add_theme_font_override("font", GameManager.font_tcm)
	_animate_in()


func close_animated() -> void:
	_kill_anim()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(_backdrop, "modulate:a", 0.0, 0.25)
	_anim_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_anim_tween.tween_callback(_on_close_done)


func _refresh() -> void:
	_title_label.text = "Archive"
	_title_label.add_theme_font_size_override("font_size", 72)
	if GameManager.font_tcm: _title_label.add_theme_font_override("font", GameManager.font_tcm)

	_slots_grid.add_theme_constant_override("h_separation", int(GAP))
	_slots_grid.add_theme_constant_override("v_separation", int(GAP))
	_slots_grid.columns = COLS
	_slots_grid.size_flags_horizontal = Control.SIZE_FILL
	_slots_grid.size_flags_vertical = Control.SIZE_FILL

	for c in _slots_grid.get_children():
		c.queue_free()

	_slots = GameManager.get_save_slots()
	for i: int in range(GameManager.MAX_SLOTS):
		_slots_grid.add_child(_make_card(i))
	_update_focus()


func _make_card(idx: int) -> Control:
	var save: SaveData = _slots[idx] if idx < _slots.size() else null

	var card := Control.new()
	card.name = "Slot_" + str(idx)
	card.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = Vector2(SLOT_W / 2.0, SLOT_H / 2.0)

	# ── 图层 0：背景填充 ──
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.15, 0.15, 0.15, 0.8)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(fill)

	# ── 图层 1：右侧 / 底部装饰条（2px 黑色，仅焦点状态）──
	var rbar := ColorRect.new()
	rbar.name = "RBar"
	rbar.color = Color.BLACK
	rbar.anchor_top = 0.0
	rbar.anchor_right = 1.0
	rbar.anchor_bottom = 1.0
	rbar.offset_left = -2.0
	rbar.visible = false
	rbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rbar)

	var bbar := ColorRect.new()
	bbar.name = "BBar"
	bbar.color = Color.BLACK
	bbar.anchor_left = 0.0
	bbar.anchor_right = 1.0
	bbar.anchor_bottom = 1.0
	bbar.offset_top = -2.0
	bbar.visible = false
	bbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bbar)

	# ── 图层 2：水印编号（52px，左上角）──
	var wm := Label.new()
	wm.name = "WM"
	wm.text = "%02d" % (idx + 1)
	wm.position = Vector2(16, 8)
	wm.add_theme_font_size_override("font_size", 52)
	wm.add_theme_color_override("font_color", Color(1, 1, 1, 0.2))
	if GameManager.font_tcm: wm.add_theme_font_override("font", GameManager.font_tcm)
	wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(wm)

	# ── 图层 2：现实日期（10px，右上角）──
	var dt := Label.new()
	dt.name = "DT"
	dt.text = save.date if save else "---- / -- / --"
	dt.anchor_right = 1.0
	dt.offset_left = -260.0
	dt.offset_right = -16.0
	dt.offset_top = 14.0
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dt.add_theme_font_size_override("font_size", 10)
	dt.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	if GameManager.font_en_body: dt.add_theme_font_override("font", GameManager.font_en_body)
	dt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dt)

	# ── 图层 2：游戏内日期（11px，右上角，DT 下方）──
	var gd_label := Label.new()
	gd_label.name = "GameDate"
	gd_label.anchor_right = 1.0
	gd_label.offset_left = -260.0
	gd_label.offset_right = -16.0
	gd_label.offset_top = 28.0
	gd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gd_label.add_theme_font_size_override("font_size", 11)
	gd_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	if GameManager.font_zh_body: gd_label.add_theme_font_override("font", GameManager.font_zh_body)
	gd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if save and not save.variables.is_empty():
		var y: int = int(save.variables.get("game_year", 0))
		var m: int = int(save.variables.get("game_month", 0))
		var d: int = int(save.variables.get("game_day", 0))
		if m > 0 and d > 0:
			if y < 2000:
				y = 2022
			if GameManager.is_locale("en"):
				var months: Array[String] = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
				gd_label.text = "%s %d, %d" % [months[m] if m < months.size() else "?", d, y]
			else:
				gd_label.text = "%d年%d月%d日" % [y, m, d]
	card.add_child(gd_label)

	# ── 图层 2：章节标题（22px，y=74）──
	var tt := Label.new()
	tt.name = "TT"
	tt.position = Vector2(16, 74)
	tt.size = Vector2(SLOT_W - 32, 28)
	tt.clip_text = true
	tt.text = save.title if save else (tr("空位"))
	tt.add_theme_font_size_override("font_size", 22)
	tt.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	@warning_ignore("static_called_on_instance")
	var tt_font: Font = GameManager.select_font(tt.text, GameManager.font_zh_title, GameManager.font_tcm)
	if tt_font: tt.add_theme_font_override("font", tt_font)
	tt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tt)

	# ── 图层 2：对话行（13px，y=104）──
	var dialogue_label := Label.new()
	dialogue_label.name = "Dialogue"
	dialogue_label.position = Vector2(16, 104)
	dialogue_label.size = Vector2(SLOT_W - 32, 20)
	dialogue_label.clip_text = true
	dialogue_label.text = save.desc if save else ""
	dialogue_label.add_theme_font_size_override("font_size", 13)
	dialogue_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	@warning_ignore("static_called_on_instance")
	var dlg_font: Font = GameManager.select_font(dialogue_label.text, GameManager.font_zh_body, GameManager.font_en_body)
	if dlg_font: dialogue_label.add_theme_font_override("font", dlg_font)
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dialogue_label)

	# ── 图层 2：详情行（10px，y=130）──
	var dl := Label.new()
	dl.name = "DL"
	dl.position = Vector2(16, 130)
	dl.text = ("SEC." + save.plot_id + " // " + save.player_name) if save else (tr("点击存档"))
	dl.add_theme_font_size_override("font_size", 10)
	dl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	@warning_ignore("static_called_on_instance")
	var dl_font: Font = GameManager.select_font(dl.text, GameManager.font_zh_body, GameManager.font_en_body)
	if dl_font: dl.add_theme_font_override("font", dl_font)
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dl)

	# ── 元数据 ──
	card.set_meta("fill", fill)
	card.set_meta("rbar", rbar)
	card.set_meta("bbar", bbar)
	card.set_meta("wm", wm)
	card.set_meta("dt", dt)
	card.set_meta("tt", tt)
	card.set_meta("dl", dl)

	card.mouse_entered.connect(_on_hover.bind(idx))
	card.gui_input.connect(_on_click.bind(idx))
	return card
func _update_focus(p_scroll: bool = false) -> void:
	for i: int in range(_slots_grid.get_child_count()):
		var card: Control = _slots_grid.get_child(i)
		var on: bool = (i == _focus_idx)
		_animate_card(card, on)

		# 仅键盘导航时自动滚动 — 鼠标悬停不应跳转到视图
		if on and p_scroll and _scroll:
			_scroll.ensure_control_visible(card)


## 将单个卡片动画化为聚焦/非聚焦状态。
## 每张卡片通过元数据拥有自己的 tween，因此终止一张卡片的
## tween 不会中断另一张卡片的动画。
func _animate_card(card: Control, on: bool) -> void:
	var fill: ColorRect = card.get_meta("fill")
	var rbar: ColorRect = card.get_meta("rbar")
	var bbar: ColorRect = card.get_meta("bbar")

	# Kill any in-progress tween on this specific card
	if card.has_meta("focus_tween"):
		var old: Tween = card.get_meta("focus_tween")
		if old and old.is_valid():
			old.kill()

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	var target_fill: Color = Color(0.35, 0.35, 0.35, 0.85) if on else Color(0.15, 0.15, 0.15, 0.8)
	tw.tween_property(fill, "color", target_fill, 0.2)

	rbar.visible = on
	bbar.visible = on

	tw.tween_property(card, "scale", Vector2(1.02, 1.02) if on else Vector2(1, 1), 0.2)

	card.set_meta("focus_tween", tw)




func _on_hover(idx: int) -> void:
	if _focus_idx == idx: return
	_focus_idx = idx
	_update_focus()
	_play_click()


func _on_click(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_play_click()
		save_selected.emit(idx)


func _on_close() -> void:
	close_animated()


func _animate_in() -> void:
	visible = true
	modulate.a = 1.0
	_setup_hint_bar()
	_kill_anim()
	_backdrop.modulate.a = 0.0
	modulate.a = 0.0
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.4)
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.35)
	for i: int in range(_slots_grid.get_child_count()):
		var c: Control = _slots_grid.get_child(i)
		c.modulate.a = 0.0
		var st := create_tween()
		st.tween_interval(i * 0.015)
		st.tween_property(c, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)


func _on_close_done() -> void:
	visible = false
	modulate.a = 1.0
	close_requested.emit()


var _back_bar: BackBar = null


func _setup_hint_bar() -> void:
	if _back_bar:  # already created — VNInterface caches SaveMenu
		return
	_back_bar = BackBar.attach(self, _on_close_back)


func _on_close_back() -> void:
	_on_close()


func _kill_anim() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null


func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed(): return
	if event.is_action_pressed("ui_cancel"):
		close_animated()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_focus_idx = max(0, _focus_idx - COLS)
		_update_focus(true); _play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_focus_idx = min(GameManager.MAX_SLOTS - 1, _focus_idx + COLS)
		_update_focus(true); _play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_focus_idx = max(0, _focus_idx - 1)
		_update_focus(true); _play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_focus_idx = min(GameManager.MAX_SLOTS - 1, _focus_idx + 1)
		_update_focus(true); _play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_play_click()
		save_selected.emit(_focus_idx)
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and _scroll:
		var bar: ScrollBar = _scroll.get_v_scroll_bar()
		var target: float = bar.value
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target = max(bar.min_value, bar.value - 200.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target = min(bar.max_value, bar.value + 200.0)
		if target != bar.value:
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw.tween_property(_scroll, "scroll_vertical", target, 0.35)


func _play_click() -> void:
	AudioManager.play_click()
