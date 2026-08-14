## QuitModal — 从 Web QuitConfirmModal 1:1 移植。
## 自包含场景。发出 confirmed() 或 cancelled() 信号。
## 符合 CLAUDE.md 规范：无 lambda，严格类型，@onready 已类型化。
extends Control

# ── Signals ────────────────────────────────────────────

signal confirmed()
signal cancelled()

# ── State ──────────────────────────────────────────────

var _sel: int = 1
var _items: Array[Control] = []
var _interactive: bool = false
var _font_zh: Font = null

# ── Onready ────────────────────────────────────────────

@onready var _dim_bg: ColorRect = $DimBg
@onready var _band: Control = $Band
@onready var _title_en: Label = $Band/BrandBox/BrandRow/TitleEn
@onready var _title_zh: Control = $Band/BrandBox/BrandRow/TitleZh
@onready var _question: Label = $Band/QuestionLabel
@onready var _opts_anchor: Control = $Band/OptionsAnchor


# ── Lifecycle ──────────────────────────────────────────

func _ready() -> void:
	_font_zh = load(GameManager.FONT_ZH_BODY)

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
	for c in _title_zh.get_children():
		c.queue_free()
	var zh_hb: HBoxContainer = HBoxContainer.new()
	zh_hb.alignment = BoxContainer.ALIGNMENT_END
	zh_hb.add_theme_constant_override("separation", 2)
	zh_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_zh.add_child(zh_hb)
	var quit_zh: String = "" if GameManager.is_locale("en") else tr("退出")
	var sizes: Array[int] = [20, 18]
	for i: int in range(quit_zh.length()):
		var l: Label = Label.new()
		l.text = quit_zh[i]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.size_flags_vertical = Control.SIZE_SHRINK_END
		l.add_theme_color_override("font_color", Color.BLACK)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if GameManager.font_zh_title: l.add_theme_font_override("font", GameManager.font_zh_title)
		var fs: int = 28 if i == 0 else sizes[(i - 1) % sizes.size()]
		l.add_theme_font_size_override("font_size", fs)
		zh_hb.add_child(l)

	# Question text (set here to avoid MCP transport encoding issues in tscn)
	_question.text = tr("确定退出吗？")
	if _font_zh: _question.add_theme_font_override("font", _font_zh)

	# Setup band pivot at right edge for scaleX (web: origin-right)
	_band.pivot_offset.x = get_viewport().get_visible_rect().size.x


# ── Entrance animation (web: band 0.4s + staggered items) ──

func _play_entrance() -> void:
	# Initial states
	_dim_bg.modulate.a = 0.0
	_band.scale.x = 0.0
	var brand_box: Control = $Band/BrandBox
	brand_box.modulate.a = 0.0
	brand_box.position.x += 50.0
	_question.modulate.a = 0.0
	_question.position.x += 50.0

	# DimBg fade + Band scaleX (web: 0.4s quint ease-out)
	var t_main: Tween = create_tween().set_parallel(true)
	t_main.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_main.tween_property(_dim_bg, "modulate:a", 1.0, 0.35)
	t_main.tween_property(_band, "scale:x", 1.0, 0.45).from(0.0)

	# BrandBox slide-in (web: delay 0.3, 0.5s)
	var t_brand: Tween = create_tween().set_parallel(true)
	t_brand.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_brand.tween_property(brand_box, "position:x", brand_box.position.x - 50.0, 0.5).set_delay(0.3)
	t_brand.tween_property(brand_box, "modulate:a", 1.0, 0.5).set_delay(0.3)

	# Question slide-in (web: delay 0.4, 0.5s)
	var t_q: Tween = create_tween().set_parallel(true)
	t_q.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_q.tween_property(_question, "position:x", _question.position.x - 50.0, 0.5).set_delay(0.4)
	t_q.tween_property(_question, "modulate:a", 1.0, 0.5).set_delay(0.4)

	# Options stagger-in (web: delay 0.5 + i*0.1, 0.5s)
	for i: int in range(_items.size()):
		var w: Control = _items[i]
		w.modulate.a = 0.0
		w.position.x = 100.0
		var d: float = 0.5 + i * 0.1
		var ti: Tween = create_tween().set_parallel(true)
		ti.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		ti.tween_property(w, "position:x", 0.0, 0.5).set_delay(d)
		ti.tween_property(w, "modulate:a", 1.0, 0.5).set_delay(d)

	# Apply initial focus highlight after entrance, then enable interaction
	var t_final: Tween = create_tween()
	t_final.tween_callback(_apply_focus).set_delay(0.6)
	t_final.tween_callback(_enable_interaction)


func _enable_interaction() -> void:
	_interactive = true


# ── Exit animation → emit signal ──────────────────────

func _play_exit(on_done: Callable) -> void:
	_interactive = false
	var brand_box: Control = $Band/BrandBox
	var tween := create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_dim_bg, "modulate:a", 0.0, 0.25)
	tween.tween_property(_band, "scale:x", 0.0, 0.25)
	tween.tween_property(brand_box, "modulate:a", 0.0, 0.2)
	tween.tween_property(_question, "modulate:a", 0.0, 0.2)
	for w: Control in _items:
		tween.tween_property(w, "modulate:a", 0.0, 0.2)
	tween.tween_callback(on_done)


# ── Options Factory ────────────────────────────────────

func _build_options() -> void:
	var is_en: bool = GameManager.is_locale("en")
	var opts: Array[Dictionary] = [
		{"en": "YES", "zh": "" if is_en else tr("是")},
		{"en": "NO",  "zh": "" if is_en else tr("否")},
	]
	for i: int in range(opts.size()):
		var row: Control = _make_option(i, opts[i].en, opts[i].zh)
		row.mouse_entered.connect(_on_hover.bind(i))
		row.gui_input.connect(_on_click.bind(i))
		_opts_anchor.add_child(row)
		_items.append(row)


func _make_option(idx: int, en_txt: String, zh_txt: String) -> Control:
	var row_wrap: Control = Control.new()
	row_wrap.name = "Opt_" + str(idx)
	row_wrap.custom_minimum_size = Vector2(0, 56)
	row_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	row_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row_wrap.offset_top = idx * 56
	row_wrap.offset_bottom = (idx + 1) * 56

	# Bar container with clipping
	var bar: Control = Control.new()
	bar.name = "Bar"
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	bar.layout_mode = 1
	bar.anchor_right = 1.0; bar.anchor_bottom = 1.0
	bar.clip_contents = true
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_wrap.add_child(bar)

	# Dark bg (web: bg-black/20)
	var bg_f: ColorRect = ColorRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	bg_f.layout_mode = 1
	bg_f.color = Color(0, 0, 0, 0.2)
	bg_f.anchor_right = 1.0; bg_f.anchor_bottom = 1.0
	bg_f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg_f)

	# Top border
	var bt: ColorRect = ColorRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	bt.layout_mode = 1
	bt.color = Color(1, 1, 1, 0.2)
	bt.anchor_right = 1.0
	bt.offset_bottom = 1.0
	bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bt)

	# Bottom border
	var bb: ColorRect = ColorRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	bb.layout_mode = 1
	bb.color = Color(1, 1, 1, 0.2)
	bb.anchor_right = 1.0
	bb.anchor_top = 1.0; bb.anchor_bottom = 1.0
	bb.offset_top = -1.0
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bb)

	# White sweep (web: bg-white sweep from left, scaleX)
	var sweep: ColorRect = ColorRect.new()
	sweep.name = "Sweep"
	sweep.color = Color.WHITE
	sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	sweep.pivot_offset = Vector2(0, 0)
	sweep.scale.x = 0.0
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(sweep)

	# Content row
	var hb: HBoxContainer = HBoxContainer.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	hb.layout_mode = 1
	hb.anchor_right = 1.0; hb.anchor_bottom = 1.0
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var en: Label = Label.new()
	en.text = en_txt
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	en.add_theme_font_size_override("font_size", 36)
	en.add_theme_color_override("font_color", Color.WHITE)
	if GameManager.font_tcm: en.add_theme_font_override("font", GameManager.font_tcm)
	hb.add_child(en)

	var zh_box: Control = Control.new()
	zh_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_zh(zh_box, zh_txt)
	hb.add_child(zh_box)

	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(150, 0)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sp)

	bar.add_child(hb)

	row_wrap.set_meta("sweep", sweep)
	row_wrap.set_meta("en", en)
	row_wrap.set_meta("zh_box", zh_box)
	return row_wrap


func _add_zh(parent: Control, text: String) -> void:
	var hb: HBoxContainer = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hb)
	var szs: Array[int] = [20, 18, 16, 18]
	for i: int in range(text.length()):
		var l: Label = Label.new()
		l.text = text[i]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.size_flags_vertical = Control.SIZE_SHRINK_END
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		if GameManager.font_zh_title: l.add_theme_font_override("font", GameManager.font_zh_title)
		var fs: int = 24 if i == 0 else szs[(i - 1) % szs.size()]
		l.add_theme_font_size_override("font_size", fs)
		hb.add_child(l)


# ── Focus & Animation ──────────────────────────────────

var _focus_tween: Tween = null

func _apply_focus() -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var base_w: float = _opts_anchor.size.x
	for i: int in range(_items.size()):
		var w: Control = _items[i]
		var sweep: ColorRect = w.get_meta("sweep")
		var en: Label = w.get_meta("en")
		var zh_box: Control = w.get_meta("zh_box")
		var foc: bool = i == _sel

		_focus_tween.tween_property(w, "size:x", base_w * 1.2 if foc else base_w, 0.2)
		_focus_tween.tween_property(w, "position:x", -30.0 if foc else 0.0, 0.2)
		_focus_tween.tween_property(w, "modulate:a", 1.0 if foc else 0.4, 0.2)
		_focus_tween.tween_property(sweep, "scale:x", 1.0 if foc else 0.0, 0.2)
		_focus_tween.tween_property(en, "self_modulate", Color.BLACK if foc else Color.WHITE, 0.2)
		_tween_zh_modulate(_focus_tween, zh_box, Color.BLACK if foc else Color.WHITE, 0.2)


func _tween_zh_modulate(tw: Tween, box: Control, col: Color, dur: float) -> void:
	for c in box.get_children():
		if c is HBoxContainer:
			for l in c.get_children():
				if l is Label:
					tw.tween_property(l, "self_modulate", col, dur)


# ── Input handlers ─────────────────────────────────────

func _on_hover(idx: int) -> void:
	if not _interactive: return
	if idx == _sel: return
	_sel = idx
	_apply_focus()
	_sfx()


func _on_click(ev: InputEvent, idx: int) -> void:
	if not _interactive: return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_sfx()
		if idx == 0:
			_confirm()
		else:
			_cancel()


func _on_dim_clicked(ev: InputEvent) -> void:
	if not _interactive: return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_sfx()
		_cancel()


func _input(event: InputEvent) -> void:
	if not _interactive: return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_sel = 0
		_apply_focus()
		_sfx()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_sel = 1
		_apply_focus()
		_sfx()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_sfx()
		if _sel == 0:
			_confirm()
		else:
			_cancel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_sfx()
		_cancel()
		get_viewport().set_input_as_handled()


func _confirm() -> void:
	_play_exit(confirmed.emit)


func _cancel() -> void:
	_play_exit(cancelled.emit)


func _sfx() -> void:
	AudioManager.play_click()
