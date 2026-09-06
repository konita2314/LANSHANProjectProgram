## QuitModal — 自包含场景。发出 confirmed() 或 cancelled() 信号。
## 选项行本体为 scenes/ui/OptionRow 统一组件（与 MainMenuList / TabMenu 同风格：
## sweep 扫白 + 位移 + 调暗 + 颜色瞬时覆盖，焦点先杀后建无半程残留），
## 本类仅编排 Modal 外壳（横条/品牌框/问题文本）与 OptionRow 的入场节奏。
## 入场照 MainMenuList：行从右侧屏外错峰滑入静止位，入场结束后才应用焦点
## （入场与焦点 tween 均写行属性，串行执行避免争抢）。
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

# 选项行入场节奏（行样式数值见 OptionRow）
const INTRO_STAGGER: float = 0.08
const OPTION_BASE_DELAY: float = 0.5

# 品牌/问题/整场节奏
const ZH_TITLE_FIRST_SIZE: int = 28
const ZH_TITLE_SIZE_CYCLE: Array[int] = [20, 18]
const ZH_TITLE_COLOR: Color = Color.BLACK
const DIM_FADE_DURATION: float = 0.35
const BAND_SCALE_DURATION: float = 0.45
const BRAND_SLIDE_DELAY: float = 0.3
const BRAND_SLIDE_DURATION: float = 0.5
const QUESTION_SLIDE_DELAY: float = 0.4
const QUESTION_SLIDE_DURATION: float = 0.5
const ENTRANCE_SLIDE_X: float = 50.0
const EXIT_DIM_DURATION: float = 0.25
const EXIT_BAND_DURATION: float = 0.25
const EXIT_FADE_DURATION: float = 0.2

# ── State ──────────────────────────────────────────────

## NO 预选（cancel-safe 默认）— 2 项非环绕。
var _selection: MenuSelection = MenuSelection.new(OPTION_DATA.size(), false, 1)
var _rows: Array[OptionRow] = []
var _interactive: bool = false

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
	# 等待选项入场完成后再应用焦点（入场与焦点 tween 均写行属性，串行避免争抢）
	await _play_option_intro()
	_apply_focus()
	_enable_interaction()


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


## 选项错峰入场（OptionRow.play_intro）：淡入先于滑动完成，等待最后一行完成。
func _play_option_intro() -> void:
	var last_tween: Tween = null
	for i: int in range(_rows.size()):
		last_tween = _rows[i].play_intro(OPTION_BASE_DELAY + i * INTRO_STAGGER)
	if last_tween:
		await last_tween.finished


func _enable_interaction() -> void:
	_interactive = true


# ── Exit animation → emit signal ──────────────────────

func _play_exit(on_done: Callable) -> void:
	_interactive = false
	_kill_focus_anims()
	var tween := create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_dim_bg, "modulate:a", 0.0, EXIT_DIM_DURATION)
	tween.tween_property(_band, "scale:x", 0.0, EXIT_BAND_DURATION)
	tween.tween_property(_brand_box, "modulate:a", 0.0, EXIT_FADE_DURATION)
	tween.tween_property(_question, "modulate:a", 0.0, EXIT_FADE_DURATION)
	for row: OptionRow in _rows:
		tween.tween_property(row, "modulate:a", 0.0, EXIT_FADE_DURATION)
	tween.tween_callback(on_done)


# ── Options Factory ────────────────────────────────────

func _build_options() -> void:
	var show_zh: bool = GameManager.is_locale("zh")
	for i: int in range(OPTION_DATA.size()):
		var option_def: Dictionary = OPTION_DATA[i]
		var en_text: String = option_def["en"]
		var zh_text: String = "" if not show_zh else tr(option_def["zh"])
		var row: OptionRow = _create_option_row(i, en_text, zh_text)
		row.hovered.connect(_on_hover)
		row.activated.connect(_on_activated)
		_opts_anchor.add_child(row)
		_rows.append(row)


func _create_option_row(index: int, en_text: String, zh_text: String) -> OptionRow:
	var row := OptionRow.new()
	row.setup(index, en_text, zh_text, GameManager.font_tcm, GameManager.font_zh_title)
	# 容器布局：锚定 OptionsAnchor 全宽、逐行堆叠
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_top = index * OptionRow.ROW_HEIGHT
	row.offset_bottom = (index + 1) * OptionRow.ROW_HEIGHT
	return row


# ── Focus & Animation ──────────────────────────────────

## 全量行焦点刷新（OptionRow 每行先杀后建，见组件注释）。
func _apply_focus() -> void:
	if _rows.is_empty():
		return
	for i: int in range(_rows.size()):
		_rows[i].apply_focus_state(i == _selection.get_selected())
	_selection.mark_focus_applied()


## 杀全部行焦点动画（出场前调用，防残留动画覆盖退出淡出）。
func _kill_focus_anims() -> void:
	for row: OptionRow in _rows:
		row.kill_focus_anim()


# ── Input handlers ─────────────────────────────────────

func _on_hover(index: int) -> void:
	if not _interactive:
		return
	if not _selection.select(index):
		return
	_apply_focus()
	_sfx()


func _on_activated(index: int) -> void:
	if not _interactive:
		return
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
