## RewardsScene : Control
## Rewards 中心（成就 + 画廊合集）— 含成就列表与音乐/场景画廊子菜单入口。

extends Control

signal back_requested()
signal gallery_requested(gallery: String)

const REST_X: float = 20.0
const FOCUS_X: float = -30.0
const FOCUS_DUR: float = 0.2

var _disabled: bool = false
var _focus_idx: int = 0
var _item_nodes: Array[Control] = []
var _item_data: Array[Dictionary] = []
var _focus_tween: Tween = null
var _entry_complete: bool = false
var _menu_active: bool = false
var _back_bar: BackBar = null

@onready var _title_label: Label = %TitleLabel
@onready var _items_container: VBoxContainer = %ItemsContainer

func _ready() -> void:
	_title_label.text = "Rewards"
	_title_label.add_theme_font_size_override("font_size", 72)
	if GameManager.font_tcm: _title_label.add_theme_font_override("font", GameManager.font_tcm)

	_item_data = [
		{"id": "Achievements", "name": "成就", "desc": "已经获得的全部游戏成就", "prog": GameManager.get_achievement_progress_percent()},
		{"id": "Music", "name": "音乐", "desc": "游戏中出现的音乐"},
		{"id": "Scenes", "name": "场景", "desc": "游戏中出现的场景"},
	]
	for i: int in range(_item_data.size()):
		var row: Control = _create_item_row(i, _item_data[i])
		_items_container.add_child(row)
		_item_nodes.append(row)

	_setup_back_button()

	_title_label.modulate.a = 0.0
	_back_bar.modulate.a = 0.0
	for w: Control in _item_nodes:
		w.modulate.a = 1.0
		w.position.x = REST_X

	await get_tree().process_frame
	await _play_entry()

func _create_item_row(index: int, data: Dictionary) -> Control:
	var container := Control.new()
	container.name = "Item_" + str(index)
	container.custom_minimum_size = Vector2(0, 110)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var sweep := ColorRect.new()
	sweep.name = "Sweep"
	sweep.color = Color.WHITE
	sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	sweep.pivot_offset = Vector2(0, 0)
	sweep.scale = Vector2(0, 1)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sweep)

	var left_bar := ColorRect.new()
	left_bar.name = "LeftBar"
	left_bar.color = Color.BLACK
	left_bar.size = Vector2(2, 110)
	left_bar.modulate.a = 0.0
	left_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(left_bar)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.position = Vector2(24, 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sub_label := Label.new()
	sub_label.name = "SubLabel"
	sub_label.text = "" if GameManager.is_locale("en") else tr(data.name)
	sub_label.visible = not GameManager.is_locale("en")
	sub_label.add_theme_font_size_override("font_size", 16)
	if GameManager.font_zh_title: sub_label.add_theme_font_override("font", GameManager.font_zh_title)
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_label)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = data.id
	title_label.add_theme_font_size_override("font_size", 34)
	if GameManager.font_tcm: title_label.add_theme_font_override("font", GameManager.font_tcm)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = tr(data.desc)
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	container.add_child(vbox)

	if "prog" in data:
		var prog_track := ColorRect.new()
		prog_track.name = "ProgTrack"
		prog_track.color = Color(1, 1, 1, 0.15)
		prog_track.size = Vector2(400, 4)
		prog_track.position = Vector2(24, 100)
		prog_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(prog_track)

		var prog_fill := ColorRect.new()
		prog_fill.name = "ProgFill"
		prog_fill.color = Color(1, 1, 1, 0.5)
		prog_fill.size = Vector2(400 * data.prog / 100.0, 4)
		prog_fill.position = Vector2(24, 100)
		prog_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(prog_fill)
		container.set_meta("prog_track", prog_track)
		container.set_meta("prog_fill", prog_fill)

		var prog_pct := Label.new()
		prog_pct.name = "ProgPct"
		prog_pct.text = str(data.prog) + "%"
		prog_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		prog_pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prog_pct.add_theme_font_size_override("font_size", 28)
		if GameManager.font_tcm: prog_pct.add_theme_font_override("font", GameManager.font_tcm)
		prog_pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prog_pct.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		prog_pct.offset_left = -120.0
		prog_pct.offset_right = -24.0
		prog_pct.offset_top = 16.0
		prog_pct.offset_bottom = 50.0
		container.add_child(prog_pct)
		container.set_meta("prog_pct", prog_pct)

	container.mouse_entered.connect(_on_hover.bind(index))
	container.gui_input.connect(_on_item_clicked.bind(index))
	container.set_meta("sweep", sweep)
	container.set_meta("left_bar", left_bar)
	container.set_meta("title_label", title_label)
	container.set_meta("sub_label", sub_label)
	container.set_meta("desc_label", desc_label)

	return container

func _play_entry() -> void:
	await get_tree().create_timer(0.15).timeout
	var t_title := create_tween()
	t_title.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t_title.tween_property(_title_label, "modulate:a", 1.0, 0.35)
	var t_back := create_tween()
	t_back.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t_back.tween_property(_back_bar, "modulate:a", 1.0, 0.25)
	_menu_active = true
	await get_tree().process_frame
	_apply_focus()
	_entry_complete = true

func _apply_focus() -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i: int in range(_item_nodes.size()):
		var row: Control = _item_nodes[i]
		var foc: bool = i == _focus_idx and _menu_active
		var active_elsewhere: bool = _menu_active and i != _focus_idx
		var sweep: ColorRect = row.get_meta("sweep")
		var left_bar: ColorRect = row.get_meta("left_bar")
		var title_label: Label = row.get_meta("title_label")
		var sub_label: Label = row.get_meta("sub_label")
		var desc_label: Label = row.get_meta("desc_label")
		_focus_tween.tween_property(row, "position:x", FOCUS_X if foc else REST_X, FOCUS_DUR)
		_focus_tween.tween_property(row, "modulate:a", 0.55 if active_elsewhere else 1.0, FOCUS_DUR)
		_focus_tween.tween_property(sweep, "scale:x", 1.0 if foc else 0.0, FOCUS_DUR)
		_focus_tween.tween_property(left_bar, "modulate:a", 1.0 if foc else 0.0, FOCUS_DUR)
		_focus_tween.tween_property(title_label, "self_modulate", Color.BLACK if foc else Color.WHITE, FOCUS_DUR)
		_focus_tween.tween_property(sub_label, "self_modulate", Color(0, 0, 0, 0.5) if foc else Color.WHITE, FOCUS_DUR)
		_focus_tween.tween_property(desc_label, "self_modulate", Color(0, 0, 0, 0.4) if foc else Color(1, 1, 1, 0.4), FOCUS_DUR)
		if row.has_meta("prog_fill"):
			var prog_track: ColorRect = row.get_meta("prog_track")
			var prog_fill: ColorRect = row.get_meta("prog_fill")
			_focus_tween.tween_property(prog_track, "color", Color(0, 0, 0, 0.12) if foc else Color(1, 1, 1, 0.15), FOCUS_DUR)
			_focus_tween.tween_property(prog_fill, "color", Color.BLACK if foc else Color(1, 1, 1, 0.5), FOCUS_DUR)
			if row.has_meta("prog_pct"):
				var prog_pct: Label = row.get_meta("prog_pct")
				_focus_tween.tween_property(prog_pct, "self_modulate", Color.BLACK if foc else Color.WHITE, FOCUS_DUR)

func _on_hover(index: int) -> void:
	if _disabled or not _menu_active or _focus_idx == index: return
	_focus_idx = index; _apply_focus(); _play_click()

func _on_item_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_activate_item(index)

func _activate_item(index: int) -> void:
	if _disabled: return
	_play_click()
	match index:
		0: gallery_requested.emit("achievements")
		1: gallery_requested.emit("music")
		2: gallery_requested.emit("scene")

func _setup_back_button() -> void:
	_back_bar = BackBar.attach(self, _on_back_pressed)

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_exit() -> void:
	_disabled = true
	_menu_active = false
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

func _on_enter() -> void:
	_disabled = false
	_refresh_translations()
	_refresh_progress()
	if _entry_complete:
		await get_tree().process_frame
		_menu_active = true
		_apply_focus()

func _refresh_translations() -> void:
	for i: int in range(_item_nodes.size()):
		var row: Control = _item_nodes[i]
		var data: Dictionary = _item_data[i]
		var sub_label: Label = row.get_meta("sub_label")
		var desc_label: Label = row.get_meta("desc_label")
		sub_label.text = "" if GameManager.is_locale("en") else tr(data.name)
		sub_label.visible = not GameManager.is_locale("en")
		desc_label.text = tr(data.desc)
	if _back_bar:
		_back_bar.set_language()

## 刷新成就进度条 — 已达成成就占全部成就的比值。
func _refresh_progress() -> void:
	if _item_nodes.is_empty():
		return
	var pct: int = GameManager.get_achievement_progress_percent()
	_item_data[0].prog = pct
	var row: Control = _item_nodes[0]
	if row.has_meta("prog_fill"):
		var prog_fill: ColorRect = row.get_meta("prog_fill")
		prog_fill.size = Vector2(400 * pct / 100.0, 4)
	if row.has_meta("prog_pct"):
		var prog_pct: Label = row.get_meta("prog_pct")
		prog_pct.text = str(pct) + "%"

func _play_click() -> void:
	AudioManager.play_click()

func _input(event: InputEvent) -> void:
	if _disabled or not _menu_active or not event.is_pressed(): return
	if event.is_action_pressed("ui_up"):
		_focus_idx = max(0, _focus_idx - 1); _apply_focus(); _play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_focus_idx = min(_item_nodes.size() - 1, _focus_idx + 1); _apply_focus(); _play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate_item(_focus_idx)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		back_requested.emit(); get_viewport().set_input_as_handled()

func set_disabled(val: bool) -> void:
	_disabled = val
