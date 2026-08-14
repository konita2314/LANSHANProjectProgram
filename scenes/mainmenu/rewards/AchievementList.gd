## AchievementList : Control
## 成就列表页 — 展示全部游戏成就的达成状态。
## 行样式与焦点动画与 RewardsScene 的选择菜单保持一致（焦点扫光 / 左侧竖条）。
##   已达成成就：可被选择；未被选择时文字为白色不透明。
##   未达成成就：常规淡化样式。
##   隐藏成就：未达成时显示 ？？？，聚焦时提示剧透，点击后揭示。
##   计数型成就：未达成时显示小字副标题 累计（x/n）次，达成后取消。
extends Control

signal back_requested()

const REST_X: float = 16.0
const FOCUS_X: float = 0.0
const FOCUS_DUR: float = 0.2
const ROW_HEIGHT: float = 96.0
const ROW_GAP: int = 8
const TODO_WIDTH: float = 420.0
const RIGHT_INSET: float = 56.0

var _disabled: bool = false
var _focus_idx: int = 0
var _row_nodes: Array[Control] = []
var _achievement_defs: Array[Dictionary] = []
var _revealed: Dictionary = {}          # 行索引 → true（仅当次浏览有效，退出场景即重置）
var _focus_tween: Tween = null
var _menu_active: bool = false
var _back_bar: BackBar = null
var _subtitle_label: Label = null


@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_container: Control = %SubtitleContainer
@onready var _items_container: VBoxContainer = %ItemsContainer
@onready var _list_scroll: ScrollContainer = $ListScroll


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:

	_title_label.text = "Achievements"
	_title_label.add_theme_font_size_override("font_size", 72)
	if GameManager.font_tcm: _title_label.add_theme_font_override("font", GameManager.font_tcm)

	# 副标题
	var sub := Label.new()
	_subtitle_label = sub
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_container.add_child(sub)

	# 列表容器 — 只允许纵向滚动，行宽固定，防止右锚定文本溢出
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_items_container.add_theme_constant_override("separation", ROW_GAP)

	_achievement_defs = GameManager.get_achievement_defs()
	for i: int in range(_achievement_defs.size()):
		var row: Control = _create_row(i)
		_items_container.add_child(row)
		_row_nodes.append(row)

	_refresh_all()
	_setup_back_button()
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)

	@warning_ignore("static_called_on_instance")
	GameManager.animate_scene_enter(self)
	await get_tree().process_frame
	_menu_active = true
	_apply_focus()


func _on_enter() -> void:
	_disabled = false
	_refresh_all()
	if _back_bar:
		_back_bar.set_language()
	await get_tree().process_frame
	_menu_active = true
	_apply_focus()


func _on_exit() -> void:
	_disabled = true
	_menu_active = false
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	# 退出场景即重置剧透揭示 — 未解锁的隐藏成就重新变为 ？？？
	if not _revealed.is_empty():
		_revealed.clear()
		for i: int in range(_row_nodes.size()):
			_update_row_texts(i)


# ===================================================================
# 行创建 — 布局：|Name        todo|，Name 下方小字副标题
# ===================================================================

func _create_row(index: int) -> Control:
	var container := Control.new()
	container.name = "Achievement_" + str(index)
	# 行宽跟随容器（不设固定最小宽度），避免溢出 ScrollContainer
	container.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# ── 焦点扫光 ──
	var sweep := ColorRect.new()
	sweep.name = "Sweep"
	sweep.color = Color.WHITE
	sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	sweep.pivot_offset = Vector2(0, 0)
	sweep.scale = Vector2(0, 1)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sweep)

	# ── 焦点左侧竖条 ──
	var left_bar := ColorRect.new()
	left_bar.name = "LeftBar"
	left_bar.color = Color.BLACK
	left_bar.size = Vector2(2, ROW_HEIGHT)
	left_bar.modulate.a = 0.0
	left_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(left_bar)

	# ── 左侧：成就名称 + 计数副标题 ──
	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.position = Vector2(24, 14)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var sub_label := Label.new()
	sub_label.name = "SubLabel"
	sub_label.add_theme_font_size_override("font_size", 12)
	sub_label.visible = false
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_label)

	container.add_child(vbox)

	# ── 右侧：达成条件（固定宽度区域，裁剪防溢出） ──
	var todo_label := Label.new()
	todo_label.name = "TodoLabel"
	todo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	todo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	todo_label.clip_text = true
	todo_label.add_theme_font_size_override("font_size", 20)
	todo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	todo_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	todo_label.offset_left = -(TODO_WIDTH + RIGHT_INSET)
	todo_label.offset_right = -RIGHT_INSET
	container.add_child(todo_label)

	# ── 右侧：剧透提示（隐藏成就聚焦时替换条件文本显示） ──
	var hint_label := Label.new()
	hint_label.name = "HintLabel"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.clip_text = true
	hint_label.visible = false
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	hint_label.offset_left = -(TODO_WIDTH + RIGHT_INSET)
	hint_label.offset_right = -RIGHT_INSET
	container.add_child(hint_label)

	container.mouse_entered.connect(_on_hover.bind(index))
	container.gui_input.connect(_on_row_clicked.bind(index))
	container.set_meta("sweep", sweep)
	container.set_meta("left_bar", left_bar)
	container.set_meta("name_label", name_label)
	container.set_meta("sub_label", sub_label)
	container.set_meta("todo_label", todo_label)
	container.set_meta("hint_label", hint_label)

	return container


# ===================================================================
# 状态与文本
# ===================================================================

## 隐藏成就在未达成且未揭示时显示 ？？？。揭示仅当次浏览有效。
func _is_concealed(index: int) -> bool:
	var def: Dictionary = _achievement_defs[index]
	if not def.hide:
		return false
	if GameManager.is_achievement_unlocked(def.id):
		return false
	return not _revealed.get(index, false)


func _update_row_texts(index: int) -> void:
	var def: Dictionary = _achievement_defs[index]
	var row: Control = _row_nodes[index]
	var concealed: bool = _is_concealed(index)
	var unlocked: bool = GameManager.is_achievement_unlocked(def.id)

	var name_label: Label = row.get_meta("name_label")
	var todo_label: Label = row.get_meta("todo_label")
	var sub_label: Label = row.get_meta("sub_label")
	var hint_label: Label = row.get_meta("hint_label")

	var name_text: String = "？？？" if concealed else tr(def.name)
	var todo_text: String = "？？？" if concealed else tr(def.todo)
	name_label.text = name_text
	todo_label.text = todo_text
	hint_label.text = tr("此成就可能会有剧透。单击以继续显示。")

	@warning_ignore("static_called_on_instance")
	var name_font: Font = GameManager.select_font(name_text, GameManager.font_zh_title, GameManager.font_tcm)
	if name_font: name_label.add_theme_font_override("font", name_font)
	@warning_ignore("static_called_on_instance")
	var todo_font: Font = GameManager.select_font(todo_text, GameManager.font_zh_body, GameManager.font_en_body)
	if todo_font: todo_label.add_theme_font_override("font", todo_font)
	@warning_ignore("static_called_on_instance")
	var hint_font: Font = GameManager.select_font(hint_label.text, GameManager.font_zh_body, GameManager.font_en_body)
	if hint_font: hint_label.add_theme_font_override("font", hint_font)

	# 计数型成就副标题 — 达成后取消
	var show_sub: bool = def.target > 0 and not unlocked and not concealed
	sub_label.visible = show_sub
	if show_sub:
		sub_label.text = tr("累计（%d/%d）次") % [GameManager.get_achievement_count(def.id), def.target]
		@warning_ignore("static_called_on_instance")
		var sub_font: Font = GameManager.select_font(sub_label.text, GameManager.font_zh_body, GameManager.font_en_body)
		if sub_font: sub_label.add_theme_font_override("font", sub_font)


func _refresh_all() -> void:
	if _subtitle_label:
		_subtitle_label.text = tr("已经获得的全部游戏成就 / Achievements")
		@warning_ignore("static_called_on_instance")
		var sub_font: Font = GameManager.select_font(_subtitle_label.text, GameManager.font_zh_body, GameManager.font_en_body)
		if sub_font: _subtitle_label.add_theme_font_override("font", sub_font)
	for i: int in range(_row_nodes.size()):
		_update_row_texts(i)
	_apply_focus()


# ===================================================================
# 焦点动画 — 与 RewardsScene 保持一致
# ===================================================================

func _apply_focus() -> void:
	if _row_nodes.is_empty():
		return
	_focus_idx = clampi(_focus_idx, 0, _row_nodes.size() - 1)
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i: int in range(_row_nodes.size()):
		var row: Control = _row_nodes[i]
		var def: Dictionary = _achievement_defs[i]
		var foc: bool = i == _focus_idx and _menu_active
		var active_elsewhere: bool = _menu_active and i != _focus_idx
		var unlocked: bool = GameManager.is_achievement_unlocked(def.id)
		var concealed: bool = _is_concealed(i)

		var sweep: ColorRect = row.get_meta("sweep")
		var left_bar: ColorRect = row.get_meta("left_bar")
		var name_label: Label = row.get_meta("name_label")
		var sub_label: Label = row.get_meta("sub_label")
		var todo_label: Label = row.get_meta("todo_label")
		var hint_label: Label = row.get_meta("hint_label")

		# 已达成成就未被选择时保持白色不透明；未达成成就常规淡化
		var rest_alpha: float = 1.0 if unlocked else (0.55 if active_elsewhere else 1.0)
		var rest_todo: Color = Color.WHITE if unlocked else Color(1, 1, 1, 0.4)

		_focus_tween.tween_property(row, "position:x", FOCUS_X if foc else REST_X, FOCUS_DUR)
		_focus_tween.tween_property(row, "modulate:a", 1.0 if foc else rest_alpha, FOCUS_DUR)
		_focus_tween.tween_property(sweep, "scale:x", 1.0 if foc else 0.0, FOCUS_DUR)
		_focus_tween.tween_property(left_bar, "modulate:a", 1.0 if foc else 0.0, FOCUS_DUR)
		_focus_tween.tween_property(name_label, "self_modulate", Color.BLACK if foc else Color.WHITE, FOCUS_DUR)
		_focus_tween.tween_property(sub_label, "self_modulate", Color(0, 0, 0, 0.5) if foc else Color(1, 1, 1, 0.5), FOCUS_DUR)
		_focus_tween.tween_property(todo_label, "self_modulate", Color(0, 0, 0, 0.6) if foc else rest_todo, FOCUS_DUR)
		_focus_tween.tween_property(hint_label, "self_modulate", Color(0, 0, 0, 0.6) if foc else Color(1, 1, 1, 0.6), FOCUS_DUR)

		# 剧透提示 — 仅在隐藏成就被选择时显示，同时隐藏 ？？？ 条件文本
		var show_hint: bool = foc and concealed
		hint_label.visible = show_hint
		todo_label.visible = not show_hint


func _scroll_to_focus() -> void:
	if _focus_idx >= 0 and _focus_idx < _row_nodes.size():
		_list_scroll.ensure_control_visible(_row_nodes[_focus_idx])


# ===================================================================
# 交互
# ===================================================================

func _on_hover(index: int) -> void:
	if _disabled or not _menu_active or _focus_idx == index:
		return
	_focus_idx = index
	_apply_focus()
	_play_click()


func _on_row_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_activate_row(index)


## 单击隐藏成就 → 揭示其内容（仅当次浏览有效，退出场景后恢复 ？？？）。
func _activate_row(index: int) -> void:
	if _disabled:
		return
	if not _is_concealed(index):
		return
	_play_click()
	_revealed[index] = true
	_update_row_texts(index)
	_apply_focus()


func _on_achievement_unlocked(_achievement_id: String) -> void:
	_refresh_all()


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
	if _disabled or not _menu_active or not event.is_pressed():
		return
	if event.is_action_pressed("ui_up"):
		_focus_idx = maxi(0, _focus_idx - 1)
		_apply_focus()
		_scroll_to_focus()
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_focus_idx = mini(_row_nodes.size() - 1, _focus_idx + 1)
		_apply_focus()
		_scroll_to_focus()
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate_row(_focus_idx)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_play_click()
		back_requested.emit()
		get_viewport().set_input_as_handled()


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
