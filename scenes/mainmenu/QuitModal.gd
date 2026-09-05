## QuitModal — 自包含场景。发出 confirmed() 或 cancelled() 信号。
## 符合 CLAUDE.md 规范：无 lambda，严格类型，@onready 已类型化。
class_name QuitModal
extends Control

# ── Signals ────────────────────────────────────────────

signal confirmed()
signal cancelled()

# ── Constants ──────────────────────────────────────────

## 语言规则（过渡方案）：非 zh locale 即隐藏中文副标题。
## 未来新增语言需在此改为按 locale 取键的字典（如 {"zh": "是", "ja": "..."}）。
const OPTION_DATA: Array[Dictionary] = [
	{ "en": "YES", "zh": "是" },
	{ "en": "NO",  "zh": "否" },
]
const ROW_HEIGHT: float = 56.0
const FOCUS_WIDTH_MULTIPLIER: float = 1.2
const FOCUS_OFFSET_X: float = -30.0
const UNFOCUSED_MODULATE: float = 0.4
const FOCUS_DURATION: float = 0.2
const SPACER_WIDTH: float = 150.0
const EN_FONT_SIZE: int = 36
const ROW_BG_COLOR: Color = Color(0, 0, 0, 0.2)
const ROW_BORDER_COLOR: Color = Color(1, 1, 1, 0.2)
const ZH_TITLE_FIRST_SIZE: int = 28
const ZH_TITLE_SIZE_CYCLE: Array[int] = [20, 18]
const ZH_TITLE_COLOR: Color = Color.BLACK
const ZH_ROW_FIRST_SIZE: int = 24
const ZH_ROW_SIZE_CYCLE: Array[int] = [20, 18, 16, 18]
const ZH_ROW_COLOR: Color = Color(1, 1, 1, 0.8)
const DIM_FADE_DURATION: float = 0.35
const BAND_SCALE_DURATION: float = 0.45
const BRAND_SLIDE_DELAY: float = 0.3
const BRAND_SLIDE_DURATION: float = 0.5
const QUESTION_SLIDE_DELAY: float = 0.4
const QUESTION_SLIDE_DURATION: float = 0.5
const OPTION_BASE_DELAY: float = 0.5
const OPTION_STAGGER: float = 0.1
const OPTION_ENTRANCE_DURATION: float = 0.5
const ENTRANCE_SLIDE_X: float = 50.0
const OPTION_INTRO_X: float = 100.0
const FOCUS_APPLY_DELAY: float = 0.6
const EXIT_DIM_DURATION: float = 0.25
const EXIT_BAND_DURATION: float = 0.25
const EXIT_FADE_DURATION: float = 0.2

# ── State ──────────────────────────────────────────────

## NO 预选（cancel-safe 默认）— 2 项非环绕。
var _selection: MenuSelection = MenuSelection.new(OPTION_DATA.size(), false, 1)
var _rows: Array[OptionRow] = []
var _interactive: bool = false
var _focus_tween: Tween = null

## 选项行类型化引用（取代 set_meta/get_meta）。
class OptionRow:
	var root: Control = null
	var sweep: ColorRect = null
	var en_label: Label = null
	var subtitle_label: SubtitleLabel = null

# ── Onready ────────────────────────────────────────────

@onready var _dim_bg: ColorRect = %DimBg
@onready var _band: Control = %Band
@onready var _brand_box: ColorRect = %BrandBox
@onready var _title_en: Label = %TitleEn
@onready var _title_zh: Control = %TitleZh
@onready var _question: Label = %QuestionLabel
@onready var _opts_anchor: Control = %OptionsAnchor


# ── Lifecycle ──────────────────────────────────────────

func _ready() -> void:
	_setup_ui()
	_build_options()
	_play_entrance()

	# Click on dim background → cancel
	_dim_bg.gui_input.connect(_on_dim_clicked)


func _setup_ui() -> void:
	# Title "Quit" font
	if GameManager.font_tcm:
		_title_en.add_theme_font_override("font", GameManager.font_tcm)

	# Chinese "退出" subtitle in the white brand box
	for child in _title_zh.get_children():
		child.queue_free()
	var quit_zh: String = "" if not GameManager.is_locale("zh") else tr("退出")
	var quit_subtitle := SubtitleLabel.new()
	quit_subtitle.set_calligraphic_text(quit_zh, ZH_TITLE_FIRST_SIZE, ZH_TITLE_SIZE_CYCLE, ZH_TITLE_COLOR, GameManager.font_zh_title)
	_title_zh.add_child(quit_subtitle)

	# Question text (set here to avoid MCP transport encoding issues in tscn)
	_question.text = tr("确定退出吗？")
	if GameManager.font_zh_body:
		_question.add_theme_font_override("font", GameManager.font_zh_body)

	# Setup band pivot at right edge for scaleX (web: origin-right)
	_band.pivot_offset.x = get_viewport().get_visible_rect().size.x


# ── Entrance animation ─────────────────────────────────

func _play_entrance() -> void:
	_set_entrance_initial_states()
	_play_entrance_tweens()
	_schedule_focus_and_enable()


func _set_entrance_initial_states() -> void:
	_dim_bg.modulate.a = 0.0
	_band.scale.x = 0.0
	_brand_box.modulate.a = 0.0
	_brand_box.position.x += ENTRANCE_SLIDE_X
	_question.modulate.a = 0.0
	_question.position.x += ENTRANCE_SLIDE_X


func _play_entrance_tweens() -> void:
	# DimBg fade + Band scaleX (web: 0.4s quint ease-out)
	var main_tween: Tween = create_tween().set_parallel(true)
	main_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	main_tween.tween_property(_dim_bg, "modulate:a", 1.0, DIM_FADE_DURATION)
	main_tween.tween_property(_band, "scale:x", 1.0, BAND_SCALE_DURATION).from(0.0)

	# BrandBox slide-in (web: delay 0.3, 0.5s)
	var brand_tween: Tween = create_tween().set_parallel(true)
	brand_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	brand_tween.tween_property(_brand_box, "position:x", _brand_box.position.x - ENTRANCE_SLIDE_X, BRAND_SLIDE_DURATION).set_delay(BRAND_SLIDE_DELAY)
	brand_tween.tween_property(_brand_box, "modulate:a", 1.0, BRAND_SLIDE_DURATION).set_delay(BRAND_SLIDE_DELAY)

	# Question slide-in (web: delay 0.4, 0.5s)
	var question_tween: Tween = create_tween().set_parallel(true)
	question_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	question_tween.tween_property(_question, "position:x", _question.position.x - ENTRANCE_SLIDE_X, QUESTION_SLIDE_DURATION).set_delay(QUESTION_SLIDE_DELAY)
	question_tween.tween_property(_question, "modulate:a", 1.0, QUESTION_SLIDE_DURATION).set_delay(QUESTION_SLIDE_DELAY)

	# Options stagger-in (web: delay 0.5 + i*0.1, 0.5s)
	for i: int in range(_rows.size()):
		var row: OptionRow = _rows[i]
		row.root.modulate.a = 0.0
		row.root.position.x = OPTION_INTRO_X
		var delay: float = OPTION_BASE_DELAY + i * OPTION_STAGGER
		var row_tween: Tween = create_tween().set_parallel(true)
		row_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		row_tween.tween_property(row.root, "position:x", 0.0, OPTION_ENTRANCE_DURATION).set_delay(delay)
		row_tween.tween_property(row.root, "modulate:a", 1.0, OPTION_ENTRANCE_DURATION).set_delay(delay)


## 入场结束后延迟应用初始焦点高亮，再开放交互。
func _schedule_focus_and_enable() -> void:
	var final_tween: Tween = create_tween()
	final_tween.tween_callback(_apply_focus).set_delay(FOCUS_APPLY_DELAY)
	final_tween.tween_callback(_enable_interaction)


func _enable_interaction() -> void:
	_interactive = true


# ── Exit animation → emit signal ──────────────────────

func _play_exit(on_done: Callable) -> void:
	_interactive = false
	var tween := create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_dim_bg, "modulate:a", 0.0, EXIT_DIM_DURATION)
	tween.tween_property(_band, "scale:x", 0.0, EXIT_BAND_DURATION)
	tween.tween_property(_brand_box, "modulate:a", 0.0, EXIT_FADE_DURATION)
	tween.tween_property(_question, "modulate:a", 0.0, EXIT_FADE_DURATION)
	for row: OptionRow in _rows:
		tween.tween_property(row.root, "modulate:a", 0.0, EXIT_FADE_DURATION)
	tween.tween_callback(on_done)


# ── Options Factory ────────────────────────────────────

func _build_options() -> void:
	var show_zh: bool = GameManager.is_locale("zh")
	for i: int in range(OPTION_DATA.size()):
		var option_def: Dictionary = OPTION_DATA[i]
		var en_text: String = option_def["en"]
		var zh_text: String = "" if not show_zh else tr(option_def["zh"])
		var row: OptionRow = _create_option_row(i, en_text, zh_text)
		row.root.mouse_entered.connect(_on_hover.bind(i))
		row.root.gui_input.connect(_on_click.bind(i))
		_opts_anchor.add_child(row.root)
		_rows.append(row)


func _create_option_row(index: int, en_text: String, zh_text: String) -> OptionRow:
	var row: OptionRow = OptionRow.new()
	row.root = Control.new()
	row.root.name = "Opt_" + str(index)
	row.root.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.root.mouse_filter = Control.MOUSE_FILTER_STOP
	row.root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.root.offset_top = index * ROW_HEIGHT
	row.root.offset_bottom = (index + 1) * ROW_HEIGHT

	var bar: Control = _create_bar(row.root)
	row.sweep = bar.get_node("Sweep") as ColorRect
	var content_row: HBoxContainer = _create_content_row(bar, en_text, zh_text)
	row.en_label = content_row.get_node("EnLabel") as Label
	row.subtitle_label = content_row.get_node("ZhSubtitle") as SubtitleLabel
	return row


## Bar 容器（clip + 深色底 + 上下边框 + 白色扫入），返回 bar。
func _create_bar(parent: Control) -> Control:
	var bar: Control = Control.new()
	bar.name = "Bar"
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	bar.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.clip_contents = true
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)

	# Dark bg (web: bg-black/20)
	var row_bg: ColorRect = ColorRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	row_bg.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	row_bg.color = ROW_BG_COLOR
	row_bg.anchor_right = 1.0
	row_bg.anchor_bottom = 1.0
	row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row_bg)

	# Top border (web: border-y border-white/20)
	var border_top: ColorRect = ColorRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	border_top.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	border_top.color = ROW_BORDER_COLOR
	border_top.anchor_right = 1.0
	border_top.offset_bottom = 1.0
	border_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(border_top)

	# Bottom border
	var border_bottom: ColorRect = ColorRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	border_bottom.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	border_bottom.color = ROW_BORDER_COLOR
	border_bottom.anchor_right = 1.0
	border_bottom.anchor_top = 1.0
	border_bottom.anchor_bottom = 1.0
	border_bottom.offset_top = -1.0
	border_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(border_bottom)

	# White sweep (web: bg-white sweep from left, scaleX)
	var sweep: ColorRect = ColorRect.new()
	sweep.name = "Sweep"
	sweep.color = Color.WHITE
	sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	sweep.pivot_offset = Vector2(0, 0)
	sweep.scale.x = 0.0
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(sweep)

	return bar


## 内容行：EN 标题 + 中文书法副标题 + 右侧间隔器，返回 content_row。
func _create_content_row(parent: Control, en_text: String, zh_text: String) -> HBoxContainer:
	var content_row: HBoxContainer = HBoxContainer.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	content_row.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	content_row.anchor_right = 1.0
	content_row.anchor_bottom = 1.0
	content_row.alignment = BoxContainer.ALIGNMENT_END
	content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(content_row)

	var en_label: Label = Label.new()
	en_label.name = "EnLabel"
	en_label.text = en_text
	en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	en_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	en_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	en_label.add_theme_font_size_override("font_size", EN_FONT_SIZE)
	en_label.add_theme_color_override("font_color", Color.WHITE)
	if GameManager.font_tcm:
		en_label.add_theme_font_override("font", GameManager.font_tcm)
	content_row.add_child(en_label)

	var zh_subtitle := SubtitleLabel.new()
	zh_subtitle.name = "ZhSubtitle"
	zh_subtitle.set_calligraphic_text(zh_text, ZH_ROW_FIRST_SIZE, ZH_ROW_SIZE_CYCLE, ZH_ROW_COLOR, GameManager.font_zh_title)
	content_row.add_child(zh_subtitle)

	# 右侧间隔器
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(SPACER_WIDTH, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(spacer)

	return content_row


# ── Focus & Animation ──────────────────────────────────

## 仅 tween 上一项与新项（首次/重置后全量）— 减少并行 tween 数量。
func _apply_focus() -> void:
	if _rows.is_empty():
		return
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	var target_indices: Array[int] = []
	if _selection.get_previous_focus() < 0:
		for i: int in range(_rows.size()):
			target_indices.append(i)
	else:
		target_indices = [_selection.get_previous_focus(), _selection.get_selected()]

	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i: int in target_indices:
		_tween_row_focus(i)
	_selection.mark_focus_applied()


func _tween_row_focus(index: int) -> void:
	var row: OptionRow = _rows[index]
	var is_focused: bool = index == _selection.get_selected()
	var base_width: float = _opts_anchor.size.x
	var target_width: float = base_width * FOCUS_WIDTH_MULTIPLIER if is_focused else base_width
	var target_x: float = FOCUS_OFFSET_X if is_focused else 0.0
	var target_alpha: float = 1.0 if is_focused else UNFOCUSED_MODULATE
	var target_sweep_scale: float = 1.0 if is_focused else 0.0
	var target_text_color: Color = Color.BLACK if is_focused else Color.WHITE
	_focus_tween.tween_property(row.root, "size:x", target_width, FOCUS_DURATION)
	_focus_tween.tween_property(row.root, "position:x", target_x, FOCUS_DURATION)
	_focus_tween.tween_property(row.root, "modulate:a", target_alpha, FOCUS_DURATION)
	_focus_tween.tween_property(row.sweep, "scale:x", target_sweep_scale, FOCUS_DURATION)
	_focus_tween.tween_property(row.en_label, "self_modulate", target_text_color, FOCUS_DURATION)
	_focus_tween.tween_property(row.subtitle_label, "self_modulate", target_text_color, FOCUS_DURATION)


# ── Input handlers ─────────────────────────────────────

func _on_hover(index: int) -> void:
	if not _interactive:
		return
	if not _selection.select(index):
		return
	_apply_focus()
	_sfx()


func _on_click(ev: InputEvent, index: int) -> void:
	if not _interactive:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_sfx()
		if index == 0:
			_confirm()
		else:
			_cancel()


func _on_dim_clicked(ev: InputEvent) -> void:
	if not _interactive:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_sfx()
		_cancel()


func _input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_sfx()
		if _selection.get_selected() == 0:
			_confirm()
		else:
			_cancel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_sfx()
		_cancel()
		get_viewport().set_input_as_handled()


func _move_selection(direction: int) -> void:
	if not _selection.move(direction):
		return
	_apply_focus()
	_sfx()


func _confirm() -> void:
	_play_exit(confirmed.emit)


func _cancel() -> void:
	_play_exit(cancelled.emit)


func _sfx() -> void:
	AudioManager.play_click()
