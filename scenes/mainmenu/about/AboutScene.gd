## AboutScene : Control
## 电影字幕风格的 about 滚动显示。
## 自动滚动；任意按键（除 ESC）加速滚动。
## ESC 或点击返回按钮退出。
extends Control

signal back_requested()

# ---------------------------------------------------------------------------
# 状态
# ---------------------------------------------------------------------------
var _scroll_position: float = 0.0
var _base_speed: float = 28.0        # pixels per second
var _boost_speed: float = 180.0      # speed when key held
var _current_speed: float = 28.0
var _is_boosting: bool = false
var _can_interact: bool = false
var _scroll_finished: bool = false
var _total_height: float = 0.0       # total text height from RichTextLabel
var _viewport_height: float = 0.0

# 字体引用
var _back_bar: BackBar = null

# ---------------------------------------------------------------------------
# Onready
# ---------------------------------------------------------------------------
@onready var _title_label: Label = %TitleLabel
@onready var _credits_viewport: Control = %CreditsViewport
@onready var _credits_text: RichTextLabel = %CreditsText
@warning_ignore("unused_private_class_variable")
@onready var _back_button: Control = %BackButton


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:
	# 纯黑色背景 — About 页面覆盖共享背景
	var black_bg := ColorRect.new()
	black_bg.name = "BlackBg"
	black_bg.color = Color(0, 0, 0, 1)
	black_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black_bg)
	move_child(black_bg, 0)


	_title_label.text = "About"
	_title_label.add_theme_font_size_override("font_size", 72)
	if GameManager.font_tcm: _title_label.add_theme_font_override("font", GameManager.font_tcm)

	_load_and_format_credits()
	_setup_back_button()


func _on_enter() -> void:
	_refresh_translations()
	# 每次访问时重置滚动状态
	_scroll_position = 0.0
	_scroll_finished = false
	_is_boosting = false
	_current_speed = _base_speed
	_can_interact = false
	_viewport_height = _credits_viewport.size.y
	await get_tree().process_frame
	_total_height = _credits_text.get_content_height()
	_credits_text.position.y = _viewport_height
	_scroll_position = _viewport_height
	_animate_enter()


func _refresh_translations() -> void:
		if _back_bar:
			_back_bar.set_language()

func _on_exit() -> void:
	_can_interact = false


# ===================================================================
# 文本加载与 BBCode 格式化
# ===================================================================

func _load_and_format_credits() -> void:
	# 预加载的 .gd 文件 — 在编辑器和导出构建中都能工作
	var about_data: RefCounted = preload("res://scripts/resources/AboutText.gd")
	var raw_text: String = about_data.TEXT

	var lines: PackedStringArray = raw_text.split("\n")
	var bbcode: String = _format_as_bbcode(lines)

	_credits_text.bbcode_enabled = true
	_credits_text.text = bbcode
	_credits_text.fit_content = true
	_credits_text.scroll_active = false   # 我们手动控制滚动
	_credits_text.set_meta("formatted", true)


func _format_as_bbcode(lines: PackedStringArray) -> String:
	var result: String = ""
	result += "\n\n"

	for line: String in lines:
		var stripped: String = line.strip_edges()

		if stripped.is_empty():
			result += "\n"
		elif stripped.begins_with("==") and stripped.ends_with("=="):
			# 主标题 — 居中，TCM 字体，大字号
			var title_text: String = stripped.trim_prefix("==").trim_suffix("==").strip_edges()
			result += "[center][font=" + GameManager.FONT_TCM + "][font_size=42]"
			result += title_text
			result += "[/font_size][/font][/center]\n\n"
		elif stripped.begins_with("---") and stripped.ends_with("---"):
			# 章节标题 — 居中，TCM 字体，中等字号
			var header_text: String = stripped.trim_prefix("---").trim_suffix("---").strip_edges()
			result += "[center][font=" + GameManager.FONT_TCM + "][font_size=30]"
			result += header_text
			result += "[/font_size][/font][/center]\n"
		elif stripped.begins_with("- "):
			# 字幕行 — 居中，正文字体
			var name_text: String = stripped.trim_prefix("- ").strip_edges()
			result += "[center][font=" + GameManager.FONT_ZH_BODY + "][font_size=22]"
			result += name_text
			result += "[/font_size][/font][/center]\n"
		else:
			# 其他行（如最后的"A FuncWork Production"）
			result += "[center][font=" + GameManager.FONT_TCM + "][font_size=28]"
			result += stripped
			result += "[/font_size][/font][/center]\n"

	result += "\n\n\n\n\n"
	return result


# ===================================================================
# 返回按钮栏（与其他场景相同的模式）
# ===================================================================

func _setup_back_button() -> void:
	_back_bar = BackBar.attach(self, _on_back_pressed)


func _on_back_pressed() -> void:
	back_requested.emit()

func _animate_enter() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "modulate:a", 1.0, 0.8)
	tween.tween_callback(_enable_interaction)


func _enable_interaction() -> void:
	_can_interact = true


# ===================================================================
# Process — 自动滚动
# ===================================================================

func _process(delta: float) -> void:
	if not _can_interact:
		return

	# 确定速度
	_current_speed = _boost_speed if _is_boosting else _base_speed

	# 已完成 — 等待自动返回
	if _scroll_finished:
		return

	# 向上滚动：减小 position.y（使文本向上移动）
	_scroll_position -= _current_speed * delta
	_credits_text.position.y = _scroll_position

	# 当所有文本滚动过顶部后，自动返回主菜单
	var text_bottom: float = _scroll_position + _total_height
	if text_bottom < 0.0:
		_scroll_finished = true
		# 结束时短暂停顿，然后淡出并返回
		var t_pause: Tween = create_tween()
		t_pause.tween_interval(1.2)
		t_pause.tween_callback(_auto_return)


func _auto_return() -> void:
	back_requested.emit()


# ===================================================================
# 输入 — 按住任意按键（除 ESC）加速
# ===================================================================

func _input(event: InputEvent) -> void:
	if not _can_interact:
		return

	# ESC 始终退出
	if event.is_action_pressed("ui_cancel"):
		_play_click()
		back_requested.emit()
		get_viewport().set_input_as_handled()
		return

	# 其他任意按键按下/释放切换加速
	if event.is_pressed():
		if event is InputEventKey or event is InputEventMouseButton:
			_is_boosting = true
	else:
		# 释放 — 检查是否还有按键按住
		if event is InputEventKey or event is InputEventMouseButton:
			_is_boosting = false


# ===================================================================
# 音频
# ===================================================================

func _play_click() -> void:
	AudioManager.play_click()


# ===================================================================
# 公共接口
# ===================================================================

func set_disabled(val: bool) -> void:
	_can_interact = not val
