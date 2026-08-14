## LoadingScreen : Control
## 全屏黑色加载覆盖层，带有脉动文本。
extends Control

@onready var _label: Label = %LoadingLabel

var _pulse_tween: Tween = null


func _ready() -> void:
	visible = false


func setup_fonts() -> void:
	@warning_ignore("static_called_on_instance")
	_label.add_theme_font_override("font", GameManager.select_font(_label.text, GameManager.font_zh_title, GameManager.font_tcm))
	_label.add_theme_font_size_override("font_size", 32)


func show_loading() -> void:
	setup_fonts()
	visible = true
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_label, "modulate:a", 0.3, 0.8)
	_pulse_tween.tween_property(_label, "modulate:a", 1.0, 0.8)


func hide_loading() -> void:
	visible = false
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
