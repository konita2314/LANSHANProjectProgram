## SettingsCycleRow : SettingsRow
## 循环选项设置行 — 自包含的标签 + < 值 > 按钮组。
## 代码构建子节点（项目惯例：BackBar 同模式）。
## 不向外暴露内部节点引用；只通过信号通信。
class_name SettingsCycleRow
extends "res://scenes/mainmenu/settings/SettingsRow.gd"

signal stepped(row_id: String, direction: int)

var _primary_label: Label = null
var _val_label: Label = null
var _prev_btn: Button = null
var _next_btn: Button = null


func _init() -> void:
	_build()


func _build() -> void:
	custom_minimum_size = Vector2(0, 68)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Sweep
	var sweep := ColorRect.new()
	sweep.name = "Sweep"
	sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	sweep.color = Color(1, 1, 1, 0.0)
	sweep.scale = Vector2(0, 1)
	sweep.pivot_offset = Vector2(0, 0)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sweep)

	# Divider
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = Color(1, 1, 1, 0.05)
	divider.size = Vector2(0, 1)
	divider.position = Vector2(24, 67)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)

	# Single HBoxContainer — label + spacer + controls in one layout, unified centering
	var content_row := HBoxContainer.new()
	content_row.name = "ContentRow"
	content_row.anchor_left = 0.0
	content_row.anchor_right = 1.0
	content_row.offset_left = 44.0
	content_row.offset_right = -40.0
	content_row.anchor_top = 0.5
	content_row.anchor_bottom = 0.5
	content_row.offset_top = -20.0
	content_row.offset_bottom = 20.0
	content_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_primary_label = Label.new()
	_primary_label.name = "PrimaryLabel"
	_primary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_primary_label.add_theme_color_override("font_color", Color.WHITE)
	_primary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_primary_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(_primary_label)

	# Spacer — pushes controls to the right
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(spacer)

	# Controls group (PrevBtn + ValLabel + NextBtn)
	var empty_style := StyleBoxEmpty.new()

	_prev_btn = Button.new()
	_prev_btn.name = "PrevBtn"
	_prev_btn.text = "<"
	_prev_btn.flat = true
	_prev_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	_prev_btn.add_theme_font_size_override("font_size", 28)
	_prev_btn.add_theme_stylebox_override("normal", empty_style)
	_prev_btn.add_theme_stylebox_override("hover", empty_style)
	_prev_btn.add_theme_stylebox_override("pressed", empty_style)
	_prev_btn.add_theme_stylebox_override("focus", empty_style)
	_prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(_prev_btn)

	_val_label = Label.new()
	_val_label.name = "ValLabel"
	_val_label.custom_minimum_size = Vector2(180, 0)
	_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_val_label.add_theme_font_size_override("font_size", 22)
	_val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_val_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(_val_label)

	_next_btn = Button.new()
	_next_btn.name = "NextBtn"
	_next_btn.text = ">"
	_next_btn.flat = true
	_next_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	_next_btn.add_theme_font_size_override("font_size", 28)
	_next_btn.add_theme_stylebox_override("normal", empty_style)
	_next_btn.add_theme_stylebox_override("hover", empty_style)
	_next_btn.add_theme_stylebox_override("pressed", empty_style)
	_next_btn.add_theme_stylebox_override("focus", empty_style)
	_next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(_next_btn)

	add_child(content_row)

	_prev_btn.pressed.connect(_on_step.bind(-1))
	_next_btn.pressed.connect(_on_step.bind(1))
	_prev_btn.mouse_entered.connect(_on_chevron_hovered.bind(_prev_btn, true))
	_prev_btn.mouse_exited.connect(_on_chevron_hovered.bind(_prev_btn, false))
	_next_btn.mouse_entered.connect(_on_chevron_hovered.bind(_next_btn, true))
	_next_btn.mouse_exited.connect(_on_chevron_hovered.bind(_next_btn, false))
	mouse_entered.connect(_emit_hovered)


func configure(p_row_id: String, zh_label: String, display_text: String) -> void:
	row_id = p_row_id
	_set_primary_text(zh_label)
	_val_label.text = display_text
	@warning_ignore("static_called_on_instance")
	var vfont: Font = GameManager.select_font(display_text, GameManager.font_zh_body, GameManager.font_tcm)
	if vfont: _val_label.add_theme_font_override("font", vfont)


func refresh_locale(data: Dictionary) -> void:
	_set_primary_text(data.zh)


func refresh_value(_settings: AppSettings, display_text: String) -> void:
	_val_label.text = display_text
	@warning_ignore("static_called_on_instance")
	var vfont: Font = GameManager.select_font(display_text, GameManager.font_zh_body, GameManager.font_tcm)
	if vfont: _val_label.add_theme_font_override("font", vfont)


func step_value(delta: float) -> void:
	stepped.emit(row_id, 1 if delta > 0.0 else -1)


func _on_step(dir: int) -> void:
	stepped.emit(row_id, dir)


func _set_primary_text(text: String) -> void:
	_primary_label.text = text
	@warning_ignore("static_called_on_instance")
	var font: Font = GameManager.select_font(text, GameManager.font_zh_body, GameManager.font_tcm)
	if font: _primary_label.add_theme_font_override("font", font)
	@warning_ignore("static_called_on_instance")
	_primary_label.add_theme_font_size_override("font_size", GameManager.select_font_size(text, 22, 26))


@warning_ignore("shadowed_variable_base_class")
func _on_chevron_hovered(btn: Button, hovered: bool) -> void:
	btn.add_theme_color_override("font_color", Color.WHITE if hovered else Color(1, 1, 1, 0.3))


func _emit_hovered() -> void:
	hovered.emit(row_id)
