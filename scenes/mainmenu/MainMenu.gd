## MainMenu : Control — 从 Web MainMenuScene 1:1 移植。
## 退出模态框已提取到 QuitModal.tscn 场景。
## 符合 CLAUDE.md 规范：无 lambda，严格类型，@onready 已类型化。
extends Control

var _sel: int = 0
var _items: Array[Control] = []
var _menu_active: bool = false
var _quit_modal: Control = null
var _overlay_tween: Tween = null  # 退出模态框变暗/恢复
var _cleaning_up: bool = false    # 防止快速按 ESC 导致重复清理
var _entry_complete: bool = false  # 初始 _play_entry() 完成后为 true

@onready var _bg_root: Control = $BgRoot
@onready var _bg_img: TextureRect = $BgRoot/BgImage
@onready var _bg_mat: ShaderMaterial = null
@onready var _brand: Control = %Branding
@onready var _brand_sub: Control = %BrandSub
@onready var _brand_line: ColorRect = %BrandLine
@onready var _brand_icon: TextureRect = %BrandIcon
@onready var _menu: Control = %MenuList


func _ready() -> void:

	# MainMenu 是透明的 — BackgroundLayer 会透过来
	_bg_img.texture = null
	_bg_img.visible = false

	_size_all()
	get_tree().root.size_changed.connect(_size_all)
	_setup_branding()
	_build_menu_items()
	_position_menu_items()
	# 短暂延迟让场景在动画开始前变得可见。
	await get_tree().process_frame
	await _play_entry()


func _size_all() -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	_bg_root.position = Vector2(-sz.x * 0.125, -sz.y * 0.125)
	_bg_root.size = Vector2(sz.x * 1.25, sz.y * 1.25)

	# 品牌信息在右上角（Web：top-12 right-12 lg:right-32）
	var brand_x: float = sz.x - 600.0
	var brand_y: float = 60.0
	_brand.position = Vector2(brand_x, brand_y)
	_brand_line.position.x = 0.0
	_brand_line.position.y = 139.0

	# 菜单项定位在右侧（Web：pr-12 lg:pr-32, max-w-xl）
	_menu.position = Vector2(sz.x - 680.0, sz.y * 0.28)
	_menu.size = Vector2(620.0, sz.y * 0.7)


func _setup_branding() -> void:
	var brand_title: Label = _brand.get_node("BrandRow/BrandTextCol/BrandTitle")
	brand_title.add_theme_font_override("font", GameManager.font_tcm)
	var footer: Label = _brand.get_node("BrandFooter")
	if GameManager.font_en_body:
		footer.add_theme_font_override("font", GameManager.font_en_body)

	var icon: Texture2D = load("res://assets/icons/icon.png")
	if icon:
		_brand_icon.texture = icon

	_add_subtitle(_brand_sub, "火兰山中学", 36, true)


func _pick_bg() -> void:
	var path: String = GameManager.current_background
	if path.is_empty() or not ResourceLoader.exists(path):
		path = GameManager.BG_POOL[randi() % GameManager.BG_POOL.size()]
	if ResourceLoader.exists(path) and _bg_img:
		var tex: Texture2D = load(path)
		GameManager.current_background = path
		_bg_img.modulate.a = 0.0
		_bg_img.texture = tex
		var tween := create_tween()
		tween.tween_property(_bg_img, "modulate:a", 1.0, 0.6)

# 将 MainMenu 背景与共享背景轮换同步（60秒定时器）
func _on_shared_bg_updated(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex and _bg_img:
		var tween := create_tween()
		tween.tween_property(_bg_img, "modulate:a", 0.0, 0.35)
		tween.tween_callback(_set_bg_texture.bind(tex))
		tween.tween_property(_bg_img, "modulate:a", 1.0, 0.35)


func _set_bg_texture(tex: Texture2D) -> void:
	if _bg_img:
		_bg_img.texture = tex



var _item_data: Array[Dictionary] = [
		{"title": "New Game",     "subtitle": "开始游戏"},
		{"title": "Load",         "subtitle": "继续游戏"},
		{"title": "Rewards",      "subtitle": "成就"},
		{"title": "Config",       "subtitle": "设置"},
		{"title": "About",        "subtitle": "关于"},
		{"title": "Exit",         "subtitle": "退出游戏"},
]

const _TARGETS: Dictionary = {
	"New Game": "REGISTRATION",
	"Load":     "LOAD",
	"Rewards":  "REWARDS",
	"Config":   "SETTINGS",
	"About":    "ABOUT",
	"Exit":     "",
}


func _build_menu_items() -> void:
	_items.clear()
	for child in _menu.get_children():
		child.queue_free()

	var is_en: bool = GameManager.is_locale("en")
	var data: Array[Dictionary] = _item_data
	for i: int in range(data.size()):
		var subtitle_label: String = "" if is_en else tr(data[i].subtitle)
		var item_wrap: Control = _make_item(i, data[i].title, subtitle_label)
		item_wrap.mouse_entered.connect(_on_hover.bind(i))
		item_wrap.gui_input.connect(_on_click.bind(i))
		_menu.add_child(item_wrap)
		_items.append(item_wrap)


func _position_menu_items() -> void:
	for i: int in range(_items.size()):
		var w: Control = _items[i]
		w.set_anchors_preset(Control.PRESET_TOP_LEFT)
		w.offset_top = i * 51
		w.offset_bottom = (i + 1) * 51
		w.offset_right = _menu.size.x
		# 开始时不可见 — _play_entry() 会按顺序淡入各项
		w.modulate.a = 0.0


## 两阶段顺序入场动画：
##   阶段 1 — Logo & 标题：短暂停顿 → 背景缩放 + 品牌信息 + 线条
##   阶段 2 — 菜单项：依次进入到静止位置 (x=20)，无弹跳
##   菜单在所有项完成入场后才变为可交互。
func _play_entry() -> void:
	# ── 初始状态 ──────────────────────────────────────────
	_bg_root.scale = Vector2(1.15, 1.15)
	_brand.modulate.a = 0.0
	var by: float = _brand.position.y
	_brand.position.y = by - 50.0
	_brand_line.size.x = 0.0
	# Menu items: hidden + off-screen right
	for w: Control in _items:
		w.modulate.a = 0.0
		w.position.x = 100.0

	# 动画开始前短暂静止 — 避免"瞬间运动"的感觉
	await get_tree().create_timer(0.2).timeout

	# ═══════════════════════════════════════════════════════════════
# 阶段 1 — Logo & 标题 （并行：背景缩放 + 品牌信息 + 线条）
# ═══════════════════════════════════════════════════════════════
	var t_bg := create_tween()
	t_bg.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_bg.tween_property(_bg_root, "scale", Vector2(1.0, 1.0), 1.2)

	var t_brand := create_tween().set_parallel(true)
	t_brand.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_brand.tween_property(_brand, "position:y", by, 1.0)
	t_brand.tween_property(_brand, "modulate:a", 1.0, 1.0)

	# 品牌线条在品牌信息部分可见后展开。
# 与品牌 tween 并行运行 — 持续到阶段 2
# 因此标题和菜单项之间没有死间隙。
	var t_line := create_tween()
	t_line.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_line.tween_property(_brand_line, "size:x", 500.0, 0.9).set_delay(0.3)
	await t_brand.finished

	# ═══════════════════════════════════════════════════════════════
# 阶段 2 — 菜单项
#   每个项快速淡入（0.3秒），让玩家尽早看到它，
#   然后在完全可见的情况下从 x=100→20 滑动 0.5 秒。
#   这避免了当淡入和滑动共享相同缓动曲线时发生的
#   "在滑动中途出现"的错觉。
#   入场后，_apply_focus() 将项 0 从 20→-30 移动 — 
#   一次平滑的向前滑动。其他项保持在 20 — 无弹跳。
# ═══════════════════════════════════════════════════════════════
	const MENU_REST_X: float = 20.0
	const FADE_DURATION: float = 0.3
	const SLIDE_DURATION: float = 0.5
	const STAGGER: float = 0.08
	var last_item_tween: Tween = null
	for i: int in range(_items.size()):
		var w: Control = _items[i]
		var d: float = i * STAGGER
		var ti := create_tween().set_parallel(true)
		ti.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		# Fast fade — item becomes fully visible early in the slide
		ti.tween_property(w, "modulate:a", 1.0, FADE_DURATION).set_delay(d)
		# Smooth slide — player sees the full motion while the item is visible
		ti.tween_property(w, "position:x", MENU_REST_X, SLIDE_DURATION).set_delay(d)
		last_item_tween = ti

	# 等待最后一项最长的动画（滑动，而非淡入），然后启用交互
	if last_item_tween:
		await last_item_tween.finished
	_menu_active = true
	# 将焦点延迟一帧 — 让任何待处理的 mouse_entered 信号
# 从滑入动画中刷新，以便正确的项
# （光标下的项，或默认的 0）获得焦点。防止
# "聚焦项 0 → 鼠标悬停项 3 → 取消并重新聚焦"的故障。
	await get_tree().process_frame
	_apply_focus()
	_entry_complete = true



func _make_item(idx: int, title_txt: String, subtitle_txt: String) -> Control:
	var item_wrap: Control = Control.new()
	item_wrap.name = "Item_" + str(idx)
	item_wrap.custom_minimum_size = Vector2(0, 51)
	item_wrap.mouse_filter = Control.MOUSE_FILTER_STOP

	var bar: Control = Control.new()
	bar.name = "Bar"
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	bar.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.clip_contents = true
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_wrap.add_child(bar)

	# 深色背景（Web：bg-black/20）
	var bg_f: ColorRect = ColorRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	bg_f.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	bg_f.color = Color(0, 0, 0, 0.2)
	bg_f.anchor_right = 1.0; bg_f.anchor_bottom = 1.0
	bg_f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg_f)

	# 顶部边框（Web：border-y border-white/20）
	var bt: ColorRect = ColorRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	bt.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	bt.color = Color(1, 1, 1, 0.2)
	bt.anchor_right = 1.0
	bt.offset_bottom = 1.0
	bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bt)

	# Bottom border
	var bb: ColorRect = ColorRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	bb.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	bb.color = Color(1, 1, 1, 0.2)
	bb.anchor_right = 1.0
	bb.anchor_top = 1.0; bb.anchor_bottom = 1.0
	bb.offset_top = -1.0
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bb)

	# 白色扫入填充（Web：bg-white，scaleX 从左原点开始）
	var sweep: ColorRect = ColorRect.new()
	sweep.name = "Sweep"
	sweep.color = Color.WHITE
	sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	sweep.pivot_offset = Vector2(0, 0)
	sweep.scale.x = 0.0
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(sweep)

	# 文本内容的 HBox（Web：flex items-end justify-between）
	var hb: HBoxContainer = HBoxContainer.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	hb.layout_mode = 1  # LAYOUT_MODE_ANCHORS
	hb.anchor_right = 1.0; hb.anchor_bottom = 1.0
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# English title
	var title: Label = Label.new()
	title.text = title_txt
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	if GameManager.font_tcm: title.add_theme_font_override("font", GameManager.font_tcm)
	hb.add_child(title)

	# 中文副标题（英文区域设置下隐藏 — 规范：英文菜单中无中文）
	var subtitle_box: Control = Control.new()
	subtitle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not subtitle_txt.is_empty():
		_add_subtitle(subtitle_box, subtitle_txt)
	hb.add_child(subtitle_box)

	# 右侧间隔器
	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(150, 0)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sp)

	bar.add_child(hb)

	item_wrap.set_meta("bar", bar)
	item_wrap.set_meta("sweep", sweep)
	item_wrap.set_meta("title", title)
	item_wrap.set_meta("subtitle_box", subtitle_box)
	item_wrap.set_meta("hb", hb)

	return item_wrap


func _add_subtitle(parent: Control, text: String, first_fs: int = 24, brand_mode: bool = false) -> void:
	var hb: HBoxContainer = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hb)

	var szs: Array[int] = []
	if brand_mode:
		szs.append(28); szs.append(24); szs.append(22); szs.append(24)
	else:
		szs.append(20); szs.append(18); szs.append(16); szs.append(18)
	for i: int in range(text.length()):
		var l: Label = Label.new()
		l.text = text[i]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.size_flags_vertical = Control.SIZE_SHRINK_END  # bottom-align in row
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		if GameManager.font_zh_title: l.add_theme_font_override("font", GameManager.font_zh_title)
		var fs: int = first_fs if i == 0 else szs[(i - 1) % szs.size()]
		l.add_theme_font_size_override("font_size", fs)
		hb.add_child(l)


var _focus_tween: Tween = null

func _apply_focus() -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i: int in range(_items.size()):
		var w: Control = _items[i]
		var sweep: ColorRect = w.get_meta("sweep")
		var title_label: Label = w.get_meta("title")
		var subtitle_box: Control = w.get_meta("subtitle_box")
		var foc: bool = i == _sel and _menu_active
		var active_elsewhere: bool = _menu_active and i != _sel

		# 仅位置偏移 — 无 size:x tween（更改布局宽度会导致
# 子元素重排 + 亚像素文本抖动）。扫入效果 + 颜色变化
# 提供足够的视觉焦点反馈。
		_focus_tween.tween_property(w, "position:x", -30.0 if foc else 20.0, 0.2)
		_focus_tween.tween_property(w, "modulate:a", 0.55 if active_elsewhere else 1.0, 0.2)
		_focus_tween.tween_property(sweep, "scale:x", 1.0 if foc else 0.0, 0.2)
		_focus_tween.tween_property(title_label, "self_modulate", Color.BLACK if foc else Color.WHITE, 0.2)
		_tween_subtitle_modulate(_focus_tween, subtitle_box, Color.BLACK if foc else Color.WHITE, 0.2)


func _tween_subtitle_modulate(tw: Tween, box: Control, col: Color, dur: float) -> void:
	for c in box.get_children():
		if c is HBoxContainer:
			for l in c.get_children():
				if l is Label:
					tw.tween_property(l, "self_modulate", col, dur)

## 发送信号到 BackgroundLayer，后者拥有缩放后的背景并处理 tween。
func _parallax() -> void:
	var vp_w: float = get_viewport().get_visible_rect().size.x
	# 将 75 px 视差摆动居中在缩放图像的额外边距内
	var center_offset: float = vp_w * (1.15 - 1.0) / 2.0
	var px: float = (_sel - 2.5) * -15.0 - center_offset
	EventBus.bg_parallax_offset.emit(px)


func _on_hover(idx: int) -> void:
	if _quit_modal or not _menu_active: return
	_sel = idx; _apply_focus(); _parallax(); _sfx()


func _on_click(ev: InputEvent, idx: int) -> void:
	if not _menu_active: return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_activate(idx)


func _activate(idx: int) -> void:
	_sfx()
	var target: String = _TARGETS.get(_item_data[idx].title, "")
	if target.is_empty():
		_show_quit()
	else:
		EventBus.scene_changed.emit(target)


func _input(event: InputEvent) -> void:
	if _quit_modal or not _menu_active:
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_sel = (_sel - 1 + 6) % 6; _apply_focus(); _parallax(); _sfx()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_sel = (_sel + 1) % 6; _apply_focus(); _parallax(); _sfx()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate(_sel); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_show_quit(); get_viewport().set_input_as_handled()


func _show_quit() -> void:
	if _quit_modal or _cleaning_up: return

	var packed: PackedScene = load("res://scenes/mainmenu/QuitModal.tscn") as PackedScene
	if not packed:
		push_error("MainMenu: Failed to load QuitModal scene")
		return

	_quit_modal = packed.instantiate()
	add_child(_quit_modal)

	_quit_modal.confirmed.connect(_on_quit_confirmed)
	_quit_modal.cancelled.connect(_on_quit_cancelled)

	_menu_active = false
	AudioManager.set_menu_mode(true)
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()
	_overlay_tween = create_tween().set_parallel(true)
	_overlay_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	for w: Control in _items:
		_overlay_tween.tween_property(w, "modulate:a", 0.15, 0.4)
	_overlay_tween.tween_property(_brand, "modulate:a", 0.3, 0.4)

	if _bg_mat: _bg_mat.set_shader_parameter("blur_amount", 15.0)
	var tbg: Tween = create_tween()
	tbg.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tbg.tween_property(_bg_root, "scale", Vector2(1.15, 1.15), 0.8)


func _on_quit_confirmed() -> void:
	await _cleanup_quit()
	get_tree().quit()


func _on_quit_cancelled() -> void:
	await _cleanup_quit()
	if _quit_modal: return
	_menu_active = true
	_apply_focus()


func _cleanup_quit() -> void:
	var modal: Control = _quit_modal
	if not modal or _cleaning_up: return
	_cleaning_up = true

	AudioManager.set_menu_mode(false)
	if _bg_mat: _bg_mat.set_shader_parameter("blur_amount", 10.0)
	var tbg: Tween = create_tween()
	tbg.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tbg.tween_property(_bg_root, "scale", Vector2(1.0, 1.0), 0.8)

	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()
	_overlay_tween = create_tween().set_parallel(true)
	_overlay_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	for w: Control in _items:
		_overlay_tween.tween_property(w, "modulate:a", 1.0, 0.3)
	_overlay_tween.tween_property(_brand, "modulate:a", 1.0, 0.3)

	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(modal):
		modal.queue_free()
	if _quit_modal == modal:
		_quit_modal = null
	_cleaning_up = false


# ── SceneManager 生命周期 ──────────────────────────────
func _on_exit() -> void:
	_menu_active = false
	_cleaning_up = false
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()
	if _quit_modal:
		_quit_modal.queue_free()
		_quit_modal = null


func _on_enter() -> void:
	_pick_bg()
	# 仅在重新进入时激活菜单（从另一个场景返回）。
# 首次加载时，_play_entry() 控制完整的动画序列，
# 并在完成时启用菜单。在此处调用 _apply_focus()
# 而入场 tweens 仍在运行会导致焦点和滑动
# tweens 争夺 position:x → 取消选择/重新选择闪烁。
	if _entry_complete:
		_build_menu_items()
		_position_menu_items()
		for w: Control in _items:
			w.modulate.a = 1.0
			w.position.x = 20.0
		await get_tree().process_frame
		_menu_active = true
		_apply_focus()


func _sfx() -> void: AudioManager.play_click()


func set_disabled(_v: bool) -> void: pass
