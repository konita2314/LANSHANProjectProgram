## LogScreen : Control
## 对话历史叠加层。
class_name LogScreen
extends Control

signal close_requested()

var _entries: Array[Dictionary] = []
var _is_open: bool = false
var _anim_tween: Tween = null

# 缓存的字体资源（在 _ready 中一次加载）
var _cached_fz_body: Font = null
var _cached_fz_title: Font = null
var _cached_fen_body: Font = null
var _cached_ftcm: Font = null
var _em_regex: RegEx = null
var _ann_regex: RegEx = null

@onready var _title_label: Label = $TitleLabel
@onready var _scroll: ScrollContainer = $EntryScroll
@onready var _list: VBoxContainer = $EntryScroll/EntryList
@onready var _hint_bar: Control = $HintBar


func _ready() -> void:
	_cached_fz_body = load(GameManager.FONT_ZH_BODY)
	_cached_fz_title = load(GameManager.FONT_ZH_TITLE)
	_cached_fen_body = load(GameManager.FONT_EN_BODY)
	_cached_ftcm = load(GameManager.FONT_TCM)
	_em_regex = RegEx.new()
	_em_regex.compile(r"\*(.+?)\*")
	_ann_regex = RegEx.new()
	_ann_regex.compile(r"==(.+?)[\(（](.+?)[\)）]==")
	_setup_title()
	_setup_hint_bar()
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	gui_input.connect(_swallow)


func _setup_title() -> void:
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	@warning_ignore("static_called_on_instance")
	var tf: Font = GameManager.select_font(_title_label.text, _cached_fz_title, _cached_ftcm)
	if tf: _title_label.add_theme_font_override("font", tf)


func _setup_hint_bar() -> void:
	if not _hint_bar:
		return

	# 使用统一 HintBar 组件 — key_first（键框在前）、组间距 32、自带 0.9 黑背景、居中、组 110×72
	var hb := HintBar.new()
	hb.setup(true, 32, true, 0.9, true, Vector2(110, 72))
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_bar.add_child(hb)

	hb.add_hint("esc", "ESC", tr("Close"), 36.0, 13)
	hb.connect_hint_action("esc", "ui_cancel")
	hb.add_hint("z", "Z", tr("Close"))
	hb.connect_hint_action("z", "vn_log")

	# 白底黑键 + 说明文字
	hb.set_hint_colors("esc", Color(1, 1, 1, 0.3), Color.WHITE, Color.BLACK)
	hb.set_hint_colors("z", Color(1, 1, 1, 0.3), Color.WHITE, Color.BLACK)

	var desc_font: Font = _cached_ftcm if _cached_ftcm else GameManager.font_tcm
	if desc_font:
		hb.set_desc_font("esc", desc_font)
		hb.set_desc_font("z", desc_font)


func open(entries: Array[Dictionary]) -> void:
	_entries = entries
	_is_open = true
	visible = true
	_kill_anim()

	if get_parent():
		position = Vector2.ZERO
		size = get_parent().size

	for c in _list.get_children():
		c.queue_free()

	_list.add_theme_constant_override("separation", 6)

	if _entries.is_empty():
		var noop := Label.new()
		noop.text = "No data"
		noop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		noop.custom_minimum_size = Vector2(0, 200)
		noop.size_flags_horizontal = Control.SIZE_FILL
		noop.add_theme_font_size_override("font_size", 24)
		noop.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
		noop.mouse_filter = MOUSE_FILTER_IGNORE
		@warning_ignore("static_called_on_instance")
		var nf: Font = GameManager.select_font(noop.text, _cached_fz_title, _cached_ftcm)
		if nf: noop.add_theme_font_override("font", nf)
		_list.add_child(noop)
	else:
		_build_entries()

	modulate.a = 0.0
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.3)

	if not _entries.is_empty():
		# 使用滚动容器宽度（基于锚点，可靠）而不是
		# VBoxContainer 宽度（基于内容，布局前可能为 0）。
		var text_w: float = _scroll.size.x - 160
		if text_w > 200:
			for c in _list.get_children():
				if c is Control and c.has_meta("tl"):
					var tl: Label = c.get_meta("tl")
					tl.size.x = text_w
			await get_tree().process_frame
			for c in _list.get_children():
				if c is Control and c.has_meta("tl"):
					var tl: Label = c.get_meta("tl")
					c.custom_minimum_size.y = tl.get_minimum_size().y + 6
		await get_tree().process_frame
		@warning_ignore("narrowing_conversion")
		_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value



func close() -> void:
	_is_open = false
	_kill_anim()
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_anim_tween.tween_callback(_on_close_done)


func _on_close_done() -> void:
	visible = false
	close_requested.emit()


func _clean_text(raw: String) -> String:
	if raw.is_empty():
		return raw
	var result: String = raw.replace("{player}", GameManager.player_name)
	if _em_regex:
		result = _em_regex.sub(result, "$1", true)
	if _ann_regex:
		result = _ann_regex.sub(result, "$1", true)
	return result

func _build_entries() -> void:
	var is_zh := _is_zh()
	var fz_body: Font = _cached_fz_body
	var fz_title: Font = _cached_fz_title
	var fen_body: Font = _cached_fen_body
	var ftcm: Font = _cached_ftcm

	for i: int in range(_entries.size()):
		var entry := _entries[i]
		var who: String = entry.get("who", "")
		var text: String = entry.get("zh", "") if is_zh else entry.get("en", "")
		if text.is_empty():
			text = entry.get("zh", "")

		var row := Control.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE

		var name_lbl := Label.new()
		name_lbl.text = who
		name_lbl.position = Vector2(0, 0)
		name_lbl.size = Vector2(140, 0)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		name_lbl.mouse_filter = MOUSE_FILTER_IGNORE
# 字体回退：带有 CJK 字符的名称需要 CJK 字体，无论地区如何
		var has_cjk: bool = false
		for ch in who:
			@warning_ignore("static_called_on_instance")
			if GameManager._is_cjk(ch):
				has_cjk = true
				break
		if has_cjk:
			if fz_title: name_lbl.add_theme_font_override("font", fz_title)
		elif not is_zh and ftcm:
			name_lbl.add_theme_font_override("font", ftcm)
		elif fz_title:
			name_lbl.add_theme_font_override("font", fz_title)
		row.add_child(name_lbl)

		var text_lbl := Label.new()
		text_lbl.text = _clean_text(text)
		text_lbl.position = Vector2(152, 0)
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_lbl.add_theme_font_size_override("font_size", 19)
		text_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		text_lbl.mouse_filter = MOUSE_FILTER_IGNORE
		@warning_ignore("static_called_on_instance")
		var tlf: Font = GameManager.select_font(text_lbl.text, fz_body, fen_body if fen_body else fz_body)
		if tlf:
			text_lbl.add_theme_font_override("font", tlf)
		row.add_child(text_lbl)
		row.set_meta("tl", text_lbl)
		_list.add_child(row)

		if i < _entries.size() - 1:
			var sep := ColorRect.new()
			sep.custom_minimum_size = Vector2(0, 8)
			sep.size_flags_horizontal = Control.SIZE_FILL
			sep.color = Color(1, 1, 1, 0.04)
			sep.mouse_filter = MOUSE_FILTER_IGNORE
			_list.add_child(sep)
func _smooth_scroll_to(target: float) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_scroll, "scroll_vertical", target, 0.25)


func _input(event: InputEvent) -> void:
	if not _is_open: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("vn_log"):
		close()
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed(): return
	if event.is_action_pressed("ui_up"):
		var bar := _scroll.get_v_scroll_bar()
		_smooth_scroll_to(max(bar.min_value, bar.value - 60.0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		var bar := _scroll.get_v_scroll_bar()
		_smooth_scroll_to(min(bar.max_value, bar.value + 60.0))
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		var bar := _scroll.get_v_scroll_bar()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_smooth_scroll_to(max(bar.min_value, bar.value - 120.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_smooth_scroll_to(min(bar.max_value, bar.value + 120.0))


func _is_zh() -> bool:
	return GameManager.is_locale("zh")


func _swallow(_e: InputEvent) -> void:
	pass


func _kill_anim() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null
