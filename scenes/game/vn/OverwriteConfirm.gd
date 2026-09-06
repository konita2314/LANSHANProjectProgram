## OverwriteConfirm : Control
## 用于确认覆盖存档的自包含模态对话框。
## 动态创建所有 UI — 只需实例化并 add_child。
## 从 App.tsx 移植的 OverwriteConfirmModal。
## 选项行为 scenes/ui/OptionRow 统一组件（与 MainMenuList / TabMenu / QuitModal 同风格）。
class_name OverwriteConfirm
extends Control

signal confirmed()
signal cancelled()

# ---------------------------------------------------------------------------
# 内部状态
# ---------------------------------------------------------------------------
var _selected_index: int = 1   # Default to "No"
var _interactive: bool = false
var _band: Control
var _branding_box: Control
var _option_nodes: Array[OptionRow] = []
var _options: Array[Dictionary] = [
	{"id": "yes", "title": "Yes", "zh": "是"},
	{"id": "no", "title": "No", "zh": "否"},
]

# 字体资源 — 在 _ready() 中加载

const BAND_PADDING: float = 64.0


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:
	# 加载字体资源

	AudioManager.set_menu_mode(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_backdrop()
	_create_band()
	_create_branding_box()
	_create_question()
	_create_options()
	_create_footer()
	_animate_enter()


# ===================================================================
# 背景遮罩（全屏深色覆盖层）
# ===================================================================

func _create_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)


# ===================================================================
# 中央带状区域
# ===================================================================

func _create_band() -> void:
	_band = Control.new()
	_band.name = "Band"
	_band.set_anchors_preset(Control.PRESET_FULL_RECT)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)

	var band_bg := ColorRect.new()
	band_bg.name = "BandBg"
	band_bg.color = Color(0, 0, 0, 0.95)
	band_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	band_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(band_bg)

	var top_border := ColorRect.new()
	top_border.name = "TopBorder"
	top_border.color = Color(1, 1, 1, 0.2)
	top_border.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_border.offset_bottom = 2.0
	top_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(top_border)

	var bottom_border := ColorRect.new()
	bottom_border.name = "BottomBorder"
	bottom_border.color = Color(1, 1, 1, 0.2)
	bottom_border.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_border.offset_top = -2.0
	bottom_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(bottom_border)


# ===================================================================
# 品牌框（覆盖带状区域顶部边缘）
# ===================================================================

func _create_branding_box() -> void:
	_branding_box = Control.new()
	_branding_box.name = "BrandingBox"
	_branding_box.position = Vector2(48, size.y / 2.0 - BAND_PADDING - 48)
	_branding_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_branding_box)

	var shadow := ColorRect.new()
	shadow.name = "Shadow"
	shadow.color = Color(1, 1, 1, 0.1)
	shadow.position = Vector2(10, 10)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_branding_box.add_child(shadow)

	var box_bg := ColorRect.new()
	box_bg.name = "BoxBg"
	box_bg.color = Color.WHITE
	box_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_branding_box.add_child(box_bg)

	# 英文标题 → TCM 字体
	var en_title := Label.new()
	en_title.name = "EnTitle"
	en_title.text = "Save"
	en_title.add_theme_color_override("font_color", Color.BLACK)
	en_title.add_theme_font_size_override("font_size", 72)
	en_title.position = Vector2(32, 16)
	en_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_tcm: en_title.add_theme_font_override("font", GameManager.font_tcm)
	_branding_box.add_child(en_title)

	# 中文标题 → SemiBold 字体
	var zh_title := Label.new()
	zh_title.name = "ZhTitle"
	zh_title.text = "" if GameManager.is_locale("en") else tr("覆盖")
	zh_title.add_theme_color_override("font_color", Color.BLACK)
	zh_title.add_theme_font_size_override("font_size", 32)
	zh_title.position = Vector2(36, 104)
	zh_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_zh_title: zh_title.add_theme_font_override("font", GameManager.font_zh_title)
	_branding_box.add_child(zh_title)

	box_bg.size = Vector2(220, 156)
	shadow.size = box_bg.size


# ===================================================================
# 问题文本
# ===================================================================

func _create_question() -> void:
	var question := Label.new()
	question.name = "Question"
	question.text = tr("确定覆盖此存档吗？")
	question.position = Vector2(48, size.y - BAND_PADDING - 48)
	question.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	question.add_theme_font_size_override("font_size", 28)
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_zh_body: question.add_theme_font_override("font", GameManager.font_zh_body)
	add_child(question)


# ===================================================================
# 选项项（是/否）
# ===================================================================

func _create_options() -> void:
	var container := VBoxContainer.new()
	container.name = "OptionsContainer"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.position = Vector2(size.x - 520, size.y / 2.0 - OptionRow.ROW_HEIGHT)
	container.custom_minimum_size = Vector2(480, OptionRow.ROW_HEIGHT * _options.size())
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	for i: int in range(_options.size()):
		var data: Dictionary = _options[i]
		var item: Control = _create_option_item(i, data)
		container.add_child(item)
		_option_nodes.append(item)

	_update_focus()


func _create_option_item(index: int, data: Dictionary) -> OptionRow:
	var zh_text: String = "" if GameManager.is_locale("en") else data.zh
	var row := OptionRow.new()
	row.setup(index, data.title, zh_text, GameManager.font_tcm, GameManager.font_zh_title, 480.0)
	row.hovered.connect(_on_option_hovered)
	row.activated.connect(_on_option_activated)
	return row


# ===================================================================
# 页脚
# ===================================================================

func _create_footer() -> void:
	var footer := Label.new()
	footer.name = "Footer"
	footer.text = "LANSHANProject 3.0.0  (C) FuncWork Studios"
	footer.position = Vector2(48, size.y - BAND_PADDING - 20)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	footer.add_theme_font_size_override("font_size", 12)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_en_body: footer.add_theme_font_override("font", GameManager.font_en_body)
	add_child(footer)


# ===================================================================
# 焦点管理
# ===================================================================

func _update_focus() -> void:
	for i: int in range(_option_nodes.size()):
		_option_nodes[i].apply_focus_state(i == _selected_index)


# ===================================================================
# 交互
# ===================================================================

func _on_option_hovered(index: int) -> void:
	if not _interactive: return
	if _selected_index != index:
		_selected_index = index
		_update_focus()
		_play_click()


func _on_option_activated(index: int) -> void:
	if not _interactive: return
	_interactive = false
	_play_click()
	if index == 0:
		confirmed.emit()
	else:
		cancelled.emit()


func _input(event: InputEvent) -> void:
	if not _interactive: return
	if not event.is_pressed():
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_selected_index = 0
		_update_focus()
		_play_click()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_selected_index = 1
		_update_focus()
		_play_click()
		get_viewport().set_input_as_handled()

		_interactive = false
	elif event.is_action_pressed("ui_accept"):
		_play_click()
		if _selected_index == 0:
			confirmed.emit()
		else:
			cancelled.emit()
		get_viewport().set_input_as_handled()

		_interactive = false
	elif event.is_action_pressed("ui_cancel"):
		_play_click()
		cancelled.emit()
		get_viewport().set_input_as_handled()


# ===================================================================
# 动画
# ===================================================================

func _animate_enter() -> void:
	if not _band:
		return
	_band.pivot_offset.x = _band.size.x
	_band.scale.x = 0.0
	modulate.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_band, "scale:x", 1.0, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_callback(_enable_interaction)


func _enable_interaction() -> void:
	_interactive = true


# ===================================================================
# 音频
# ===================================================================

func _play_click() -> void:
	AudioManager.play_click()


# ===================================================================
# 清理
# ===================================================================

func _exit_tree() -> void:
	AudioManager.set_menu_mode(false)
