## SubtitleLabel : HBoxContainer
## 书法式中文副标题 — 逐字 Label 首字大、其余按周期循环字号。
## 实现与 TabMenu 选项 / 重构前 git 版 _add_subtitle 一致：纯 Label + 显式字号覆盖，
## 尺寸由字体度量稳定决定，不依赖 RichTextLabel。
## 曾用 RichTextLabel（fit_content + [font_size] BBCode）实现，在 Godot 4 中
## fit_content 行高按默认字号计算导致大号首字被纵向裁切（"字体不完全显示"），
## 且容器内尺寸振荡引发每帧重排（"动画卡顿"），故回退为逐字 Label 方案。
## 聚焦变色由调用方直接 tween 本节点的 self_modulate（modulate 自动传导子 Label）。
## 纯组件：不触碰 GameManager/EventBus/AudioManager，字体与颜色经参数传入。
class_name SubtitleLabel
extends HBoxContainer


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 默认 STOP 会截断所在行的 mouse_entered
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	size_flags_vertical = Control.SIZE_SHRINK_END  # HBox 内底对齐（对齐原逐字 Label 行为）


## 设置书法式文本：逐字 Label（首字 p_first_font_size，其余按 p_size_cycle 周期循环）。
## p_text 为空时清空（英文模式隐藏副标题）。
func set_calligraphic_text(p_text: String, p_first_font_size: int, p_size_cycle: Array[int], p_color: Color, p_font: Font) -> void:
	for child: Node in get_children():
		child.queue_free()
	if p_text.is_empty():
		return
	var effective_cycle: Array[int] = p_size_cycle if not p_size_cycle.is_empty() else [p_first_font_size]
	for i: int in range(p_text.length()):
		var label: Label = Label.new()
		label.text = p_text[i]
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.size_flags_vertical = Control.SIZE_SHRINK_END
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", p_color)
		if p_font:
			label.add_theme_font_override("font", p_font)
		var font_size: int = p_first_font_size if i == 0 else effective_cycle[(i - 1) % effective_cycle.size()]
		label.add_theme_font_size_override("font_size", font_size)
		add_child(label)
	_sync_size()


## 非容器父节点（如 BrandSub）不会接管子节点尺寸：按内容显式设定自身尺寸，
## 保证逐字 Label 不被 0 尺寸裁切。容器父节点由容器排序接管，无需处理。
func _sync_size() -> void:
	if not is_inside_tree():
		return
	if get_parent() is Container:
		return
	size = get_combined_minimum_size()


## 离树创建路径（text 先设后入树）在入树时补一次尺寸同步。
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_sync_size()
