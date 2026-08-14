## SettingsSliderRow : SettingsRow
## 滑块设置行 — 自包含的标签 + 轨道/填充/拇指/滑块控件。
## 代码构建子节点（项目惯例：BackBar 同模式）。
## 不向外暴露内部节点引用；只通过信号通信。
class_name SettingsSliderRow
extends "res://scenes/mainmenu/settings/SettingsRow.gd"

signal value_changed(value: float, row_id: String)

const TRACK_W: float = 400.0
const THUMB_SIZE: float = 24.0

var _setting_key: String = ""

var _primary_label: Label = null
var _track_fill: ColorRect = null
var _thumb: ColorRect = null
var _slider: HSlider = null


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

	# PrimaryLabel — direct child, anchor-centered, text vertically centered
	_primary_label = Label.new()
	_primary_label.name = "PrimaryLabel"
	_primary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_primary_label.anchor_top = 0.5
	_primary_label.anchor_bottom = 0.5
	_primary_label.offset_top = -20.0
	_primary_label.offset_bottom = 20.0
	_primary_label.offset_left = 44.0
	_primary_label.offset_right = 400.0
	_primary_label.add_theme_color_override("font_color", Color.WHITE)
	_primary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_primary_label)

	# SliderTrack — right-anchored + vertically centered
	var track_container := Control.new()
	track_container.name = "SliderTrack"
	track_container.anchor_left = 1.0
	track_container.anchor_right = 1.0
	track_container.offset_left = -(TRACK_W + 40.0)
	track_container.offset_right = -40.0
	track_container.anchor_top = 0.5
	track_container.anchor_bottom = 0.5
	track_container.offset_top = -(THUMB_SIZE / 2.0)
	track_container.offset_bottom = THUMB_SIZE / 2.0
	track_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var track_bg := ColorRect.new()
	track_bg.name = "TrackBg"
	track_bg.color = Color(1, 1, 1, 0.1)
	track_bg.size = Vector2(TRACK_W, 4)
	track_bg.position = Vector2(0, 10)
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_container.add_child(track_bg)

	_track_fill = ColorRect.new()
	_track_fill.name = "TrackFill"
	_track_fill.color = Color(1, 1, 1, 0.6)
	_track_fill.size = Vector2(0, 4)
	_track_fill.position = Vector2(0, 10)
	_track_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_container.add_child(_track_fill)

	_thumb = ColorRect.new()
	_thumb.name = "Thumb"
	_thumb.color = Color.BLACK
	_thumb.size = Vector2(THUMB_SIZE, THUMB_SIZE)
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_container.add_child(_thumb)

	_slider = HSlider.new()
	_slider.name = "HSlider"
	_slider.size = Vector2(TRACK_W, THUMB_SIZE)
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.modulate.a = 0.0
	_slider.add_theme_stylebox_override("slider", StyleBoxEmpty.new())
	_slider.add_theme_stylebox_override("grabber", StyleBoxEmpty.new())
	_slider.add_theme_stylebox_override("grabber_highlight", StyleBoxEmpty.new())
	track_container.add_child(_slider)

	add_child(track_container)

	_slider.value_changed.connect(_on_slider_changed)
	mouse_entered.connect(_emit_hovered)


func configure(p_row_id: String, zh_label: String, initial_value: float, setting_key: String) -> void:
	row_id = p_row_id
	_setting_key = setting_key
	_set_primary_text(zh_label)
	_slider.set_value_no_signal(initial_value)
	_update_track(initial_value)


func refresh_locale(data: Dictionary) -> void:
	_set_primary_text(data.zh)


func refresh_value(settings: AppSettings, _display_text: String) -> void:
	var v: float = settings.get_prop(_setting_key)
	_slider.set_value_no_signal(v)
	_update_track(v)


func step_value(delta: float) -> void:
	_slider.value = clampf(_slider.value + delta, 0.0, 1.0)


func get_value() -> float:
	return _slider.value


func _on_slider_changed(value: float) -> void:
	_update_track(value)
	value_changed.emit(value, row_id)


func _update_track(value: float) -> void:
	_track_fill.size.x = TRACK_W * value
	var cx: float = TRACK_W * value
	_thumb.position.x = clampf(cx - THUMB_SIZE / 2.0, 0.0, TRACK_W - THUMB_SIZE)


func _set_primary_text(text: String) -> void:
	_primary_label.text = text
	@warning_ignore("static_called_on_instance")
	var font: Font = GameManager.select_font(text, GameManager.font_zh_body, GameManager.font_tcm)
	if font: _primary_label.add_theme_font_override("font", font)
	@warning_ignore("static_called_on_instance")
	_primary_label.add_theme_font_size_override("font_size", GameManager.select_font_size(text, 22, 26))


func _emit_hovered() -> void:
	hovered.emit(row_id)
