## SettingsSectionHeader : Control
## 设置分区标题 — 代码构建（项目惯例：BackBar 同模式）。
## 含英文标签、中文标签和描述文本。语言切换时通过 refresh_locale() 更新。
class_name SettingsSectionHeader
extends Control

var _zh_label: Label = null
var _desc_label: Label = null
var _spacer: Control = null


func _init() -> void:
	_build()


func _build() -> void:
	custom_minimum_size = Vector2(0, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_spacer = Control.new()
	_spacer.name = "Spacer"
	_spacer.custom_minimum_size = Vector2(0, 24)
	_spacer.visible = false
	add_child(_spacer)

	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.color = Color.WHITE
	dot.size = Vector2(8, 8)
	dot.position = Vector2(24, 12)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)

	var en_label := Label.new()
	en_label.name = "SectionEn"
	en_label.position = Vector2(44, 6)
	en_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	en_label.add_theme_font_size_override("font_size", 18)
	if GameManager.font_tcm: en_label.add_theme_font_override("font", GameManager.font_tcm)
	en_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(en_label)

	_zh_label = Label.new()
	_zh_label.name = "SectionZh"
	_zh_label.position = Vector2(140, 8)
	_zh_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	_zh_label.add_theme_font_size_override("font_size", 16)
	if GameManager.font_zh_title: _zh_label.add_theme_font_override("font", GameManager.font_zh_title)
	_zh_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_zh_label)

	_desc_label = Label.new()
	_desc_label.name = "SectionDesc"
	_desc_label.position = Vector2(44, 34)
	_desc_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	_desc_label.add_theme_font_size_override("font_size", 13)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc_label)


func configure(en_text: String, zh_text: String, desc: String, is_first: bool) -> void:
	_spacer.visible = not is_first

	var en_label: Label = get_node("SectionEn") as Label
	en_label.text = en_text

	var is_en: bool = GameManager.is_locale("en")
	_zh_label.text = zh_text
	_zh_label.visible = not is_en

	if not desc.is_empty():
		_desc_label.text = desc
		@warning_ignore("static_called_on_instance")
		var desc_font: Font = GameManager.select_font(desc, GameManager.font_zh_body, GameManager.font_en_body)
		if desc_font: _desc_label.add_theme_font_override("font", desc_font)


## 语言切换 — 更新中文标签可见性和描述文本。
func refresh_locale(zh_text: String, desc: String) -> void:
	var is_en: bool = GameManager.is_locale("en")
	_zh_label.text = zh_text
	_zh_label.visible = not is_en

	_desc_label.text = desc
	@warning_ignore("static_called_on_instance")
	var desc_font: Font = GameManager.select_font(desc, GameManager.font_zh_body, GameManager.font_en_body)
	if desc_font: _desc_label.add_theme_font_override("font", desc_font)
