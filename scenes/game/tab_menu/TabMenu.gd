## TabMenu : Control
## 游戏内Tab菜单 — 重新设计以匹配 QuitConfirm 模态框风格。
## 多级菜单：主菜单 → 系统 → 配置。按Tab键打开，ESC键关闭。
class_name TabMenu
extends Control

enum MenuLevel { MAIN, SYSTEM, SIDESTORY }

signal close_requested()
signal back_to_title()
signal open_settings()
signal open_map()
signal open_calendar()
signal open_sidestory(story_id: String)
signal sidestory_back_requested()

# ---------------------------------------------------------------------------
# 状态
# ---------------------------------------------------------------------------
var _level: MenuLevel = MenuLevel.MAIN
var _focus_idx: int = 0
var _is_open: bool = false
var _restricted: bool = false   # true 时仅允许 System 层级菜单（序章未完结）
var _anim_tween: Tween = null
var _entry_tweens: Array[Tween] = []

# ── 入场焦点保护 ──
var _entrance_focus_token: int = 0
# 保存每一行的焦点动画，避免新旧 tween 争抢
var _row_focus_tweens: Array[Tween] = []

# ── 返回标题确认对话框 ──────────────────────────────
var _confirm_active: bool = false
var _confirm_sel: int = 1          # 默认选中 "No 否"
var _confirm_option_nodes: Array[Control] = []
var _confirm_band: Control = null
var _confirm_focus_tween: Tween = null
var _confirm_interactive: bool = false

const CONFIRM_OPTIONS: Array[Dictionary] = [
	{"id": "yes", "title": "Yes", "label": "是"},
	{"id": "no",  "title": "No",  "label": "否"},
]


var _main_options: Array[Dictionary] = []
var _system_options: Array[Dictionary] = []
var _sidestory_options: Array[Dictionary] = []
var _sidestory_mode: bool = false
var _sidestory_list: Array[Dictionary] = []

# UI 节点（来自 .tscn — 静态结构）
@onready var _darken_overlay: ColorRect = $DarkenBg
@onready var _band: Control = $Band
@onready var _branding: Control = $Branding
@onready var _branding_shadow: ColorRect = $Branding/BrandingShadow
@onready var _branding_box: ColorRect = $Branding/BrandingBox
@onready var _branding_label: Label = $Branding/BrandingLabel
@onready var _level_label: Label = $LevelLabel
@onready var _title_label: Label = $TitleLabel
@onready var _subtitle_label: Label = $SubtitleLabel
@onready var _desc_label: Label = $DescLabel
@onready var _options_container: VBoxContainer = $OptionsContainer

const OPTION_HEIGHT: float = 51.0
const BAND_PAD: float = 64.0


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:

	# 阻止所有输入传递到后面的界面。
	# TSCN 中已连接，代码连接作为兜底（兼容 TabMenu.new()）
	if not gui_input.is_connected(_swallow_input):
		gui_input.connect(_swallow_input)

	_setup_options()
	_apply_layout()
	_apply_fonts()
	_build_confirm_dialog()


func _setup_options() -> void:
	_main_options = [
		{"id": "Item",       "name": "物品", "desc": "查看现有的物品。"},
		{"id": "Terminal",   "name": "终端", "desc": "访问终端。"},
		{"id": "Profile",    "name": "档案", "desc": "记录有关人物的背景资料。"},
		{"id": "Story",      "name": "故事", "desc": "回顾已经历过的剧情节点。"},
		{"id": "Data",       "name": "资料", "desc": "整理收集到的线索。"},
		{"id": "Calendar",   "name": "日程", "desc": "查看日程表。"},
		{"id": "Map",        "name": "地图", "desc": "查看校园地图。"},
		{"id": "System",     "name": "系统", "desc": "管理游戏选项。"},
	]
	if _sidestory_mode:
		_system_options = [
			{"id": "Config", "name": "设置",     "desc": "变更游戏设定。"},
			{"id": "Back",   "name": "返回主线", "desc": "退出支线剧情，返回主线剧情。"},
		]
	else:
		_system_options = [
			{"id": "Config",   "name": "设置",     "desc": "变更游戏设定。"},
			{"id": "Back",     "name": "返回菜单", "desc": "返回上一级菜单。"},
			{"id": "Title",    "name": "返回标题", "desc": "返回主界面。"},
		]
		_sidestory_options = _sidestory_list.duplicate()
		# 没有已注册的支线时隐藏"资料"入口
		if _sidestory_list.is_empty():
			var filtered: Array[Dictionary] = []
			for o in _main_options:
				if o.id != "Data":
					filtered.append(o)
			_main_options = filtered


# ===================================================================
# 静态节点初始化（视口相关位置 + 字体）
# ===================================================================

func _apply_layout() -> void:
	var vp_h: float = get_viewport().get_visible_rect().size.y
	_branding.position = Vector2(48, vp_h / 2.0 - BAND_PAD - 48)
	_branding_shadow.size = _branding_box.size
	_level_label.position = Vector2(48, vp_h / 2.0 + BAND_PAD + 20)
	_title_label.position = Vector2(48, vp_h / 2.0 + BAND_PAD + 36)
	_subtitle_label.position = Vector2(48, vp_h / 2.0 + BAND_PAD + 76)
	_desc_label.position = Vector2(48, vp_h / 2.0 + BAND_PAD + 100)


func _apply_fonts() -> void:
	if GameManager.font_tcm:
		_branding_label.add_theme_font_override("font", GameManager.font_tcm)
		_level_label.add_theme_font_override("font", GameManager.font_tcm)
		_title_label.add_theme_font_override("font", GameManager.font_tcm)

	if GameManager.font_zh_title:
		_subtitle_label.add_theme_font_override("font", GameManager.font_zh_title)

	if GameManager.font_zh_body:
		_desc_label.add_theme_font_override("font", GameManager.font_zh_body)


# ===================================================================
# 打开 / 关闭
# ===================================================================

func open(terminal_status: String = "locked", full_menu: bool = true, _bg_path: String = "", sidestory_list: Array[Dictionary] = []) -> void:
	_is_open = true
	_restricted = not full_menu
	_sidestory_list = sidestory_list
	if _sidestory_mode or _restricted:
		_level = MenuLevel.SYSTEM; _focus_idx = 0
	else:
		_level = MenuLevel.MAIN; _focus_idx = 0

	# 强制尺寸填满视口 — 这对鼠标输入拦截至关重要
	var vs := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vs

	_setup_options()
	if terminal_status == "locked":
		var f: Array[Dictionary] = []
		for o in _main_options:
			if o.id != "Terminal": f.append(o)
		_main_options = f

	# 受限模式下保留 Back —— 行为改为 close()，文案改为返回游戏
	if _restricted:
		for o in _system_options:
			if o.id == "Back":
				o.name = "返回游戏"
	_refresh_options()
	_animate_enter()


func close() -> void:
	_is_open = false
	_kill_anim()

	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_anim_tween.tween_callback(_on_close_done)


func _on_close_done() -> void:
	visible = false
	close_requested.emit()


# ===================================================================
# 动画
# ===================================================================

func _animate_enter() -> void:
	visible = true
	_kill_anim()

	# 立即设置不透明状态
	_darken_overlay.color.a = 0.55
	_band.scale.x = 1.0

	# Fade self + options in smoothly
	modulate.a = 0.0
	_entry_tweens.clear()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	for i: int in range(_options_container.get_child_count()):
		var c := _options_container.get_child(i)
		c.modulate.a = 0.0
		var st := create_tween()
		st.tween_interval(0.2 + i * 0.04)
		st.tween_property(c, "modulate:a", 1.0, 0.2)
		_entry_tweens.append(st)

	# 焦点延迟设置 — 用 token 防止用户操作后又被强行拉回
	var token: int = _entrance_focus_token + 1
	_entrance_focus_token = token
	var row_count: int = _options_container.get_child_count()
	var focus_delay: float = 0.46 + row_count * 0.04
	var focus_tween := create_tween()
	focus_tween.tween_interval(focus_delay)
	focus_tween.tween_callback(func():
		if _entrance_focus_token == token:  # 没有被取消
			_update_focus()
	)
	_entry_tweens.append(focus_tween)



# ===================================================================
# 选项
# ===================================================================

func _refresh_options() -> void:
	for c in _options_container.get_children():
		_options_container.remove_child(c)
		c.queue_free()

	var opts := _get_current_options()
	var vp_w: float = get_viewport().get_visible_rect().size.x
	_options_container.position = Vector2(vp_w - 520, get_viewport().get_visible_rect().size.y / 2.0 - OPTION_HEIGHT * opts.size() / 2.0)

	for i: int in range(opts.size()):
		var row := _make_row(i, opts[i])
		_options_container.add_child(row)

	_update_level_display()
	_update_focus()


func _get_current_options() -> Array[Dictionary]:
	match _level:
		MenuLevel.MAIN:      return _main_options
		MenuLevel.SYSTEM:    return _system_options
		MenuLevel.SIDESTORY: return _sidestory_options
	return []


func _make_row(idx: int, data: Dictionary) -> Control:
	var row_wrap := Control.new()
	row_wrap.custom_minimum_size = Vector2(480, OPTION_HEIGHT)
	row_wrap.mouse_filter = MOUSE_FILTER_STOP

	var sweep := ColorRect.new()
	sweep.color = Color.WHITE; sweep.size = Vector2(480, OPTION_HEIGHT)
	sweep.scale.x = 0.0; sweep.mouse_filter = MOUSE_FILTER_IGNORE
	row_wrap.add_child(sweep)

	var hb := HBoxContainer.new()
	hb.size = Vector2(480, OPTION_HEIGHT); hb.alignment = BoxContainer.ALIGNMENT_END
	hb.mouse_filter = MOUSE_FILTER_IGNORE
	row_wrap.add_child(hb)

	# Spacer
	var sp := Control.new(); sp.custom_minimum_size = Vector2(16, 0); sp.mouse_filter = MOUSE_FILTER_IGNORE
	hb.add_child(sp)

	# 英文标签（始终为英文 — 设计元素）
	var id := Label.new()
	id.text = data.id
	id.add_theme_font_size_override("font_size", 42)
	id.mouse_filter = MOUSE_FILTER_IGNORE
	if GameManager.font_tcm: id.add_theme_font_override("font", GameManager.font_tcm)
	hb.add_child(id)

	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(12, 0); sp2.mouse_filter = MOUSE_FILTER_IGNORE
	hb.add_child(sp2)

	# 翻译后的标签 — 使用 tr() 以便非中文本地化模式显示正确文本
	@warning_ignore("shadowed_variable_base_class")
	var name := Label.new()
	name.text = "" if GameManager.is_locale("en") else tr(data.name)
	name.add_theme_font_size_override("font_size", 24)
	name.mouse_filter = MOUSE_FILTER_IGNORE
	@warning_ignore("static_called_on_instance")
	name.add_theme_font_override("font", GameManager.select_font(name.text, GameManager.font_zh_title, GameManager.font_tcm))
	hb.add_child(name)

	row_wrap.mouse_entered.connect(_on_hover.bind(idx))
	row_wrap.gui_input.connect(_on_click.bind(idx))
	row_wrap.set_meta("sweep", sweep)
	row_wrap.set_meta("en_label", id)
	row_wrap.set_meta("name_label", name)
	row_wrap.set_meta("option_id", data.get("id", ""))
	return row_wrap


# ===================================================================
# 层级显示
# ===================================================================

func _update_level_display() -> void:
	match _level:
		MenuLevel.MAIN:      _level_label.text = "MAIN"
		MenuLevel.SYSTEM:    _level_label.text = "SYSTEM"
		MenuLevel.SIDESTORY: _level_label.text = "SIDESTORY"

	var opts := _get_current_options()
	if _focus_idx >= 0 and _focus_idx < opts.size():
		var d := opts[_focus_idx]
		_title_label.text = d.get("id", "")
		_subtitle_label.text = "" if GameManager.is_locale("en") else tr(d.name)
		@warning_ignore("static_called_on_instance")
		_subtitle_label.add_theme_font_override("font", GameManager.select_font(_subtitle_label.text, GameManager.font_zh_title, GameManager.font_tcm))
		_desc_label.text = tr(d.desc)
		@warning_ignore("static_called_on_instance")
		_desc_label.add_theme_font_override("font", GameManager.select_font(_desc_label.text, GameManager.font_zh_body, GameManager.font_en_body))


# ===================================================================
# 焦点
# ===================================================================

func _update_focus() -> void:
	# 杀掉上一轮所有行的焦点动画，避免重叠
	for tw: Tween in _row_focus_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_row_focus_tweens.clear()

	for i: int in range(_options_container.get_child_count()):
		var row := _options_container.get_child(i) as Control
		var on := i == _focus_idx
		var sweep: ColorRect = row.get_meta("sweep")
		var en: Label = row.get_meta("en_label")
		var zh: Label = row.get_meta("name_label")

		# "终端 Terminal" 未选中时也比其他选项更亮，保持视觉突出
		var is_terminal: bool = (row.get_meta("option_id") == "Terminal")
		var unsel_alpha: float = 0.65 if is_terminal else 0.35
		var unsel_zh_color: Color = Color(1, 1, 1, 0.75) if is_terminal else Color(1, 1, 1, 0.5)

		var tw := create_tween().set_parallel(true)
		_row_focus_tweens.append(tw)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(sweep, "scale:x", 1.0 if on else 0.0, 0.25)
		tw.tween_property(row, "position:x", -50.0 if on else 10.0, 0.25)
		tw.tween_property(row, "modulate:a", 1.0 if on else unsel_alpha, 0.25)

		en.add_theme_color_override("font_color", Color.BLACK if on else Color.WHITE)
		zh.add_theme_color_override("font_color", Color(0, 0, 0, 0.6) if on else unsel_zh_color)

	_update_level_display()


# ===================================================================
# 交互
# ===================================================================

func _on_hover(idx: int) -> void:
	if _focus_idx == idx: return
	_entrance_focus_token += 1
	_focus_idx = idx; _update_focus(); _play_click()


func _on_click(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_focus_idx = idx; _update_focus(); _handle_action(0); _play_click()


func _handle_action(dir: int) -> void:
	_play_click()
	# dir: 0=鼠标点击, 1=Enter/Space/→, -1=←
	# MAIN / SYSTEM 没有 +/- 调节语义，全部方向都视为确认选择
	var confirm: bool = (dir == 0 or dir == 1)
	match _level:
		MenuLevel.MAIN:
			var o := _main_options[_focus_idx]
			if o.id == "System" and confirm:
				_level = MenuLevel.SYSTEM; _focus_idx = 0; _refresh_options()
			if o.id == "Calendar" and confirm:
				_is_open = false
				visible = false
				close_requested.emit()
				open_calendar.emit()
			if o.id == "Map" and confirm:
				_is_open = false
				visible = false
				close_requested.emit()
				open_map.emit()
			if o.id == "Data" and confirm:
				_level = MenuLevel.SIDESTORY; _focus_idx = 0; _refresh_options()
		MenuLevel.SYSTEM:
			var o := _system_options[_focus_idx]
			match o.id:
				"Config":
					if confirm:
						_is_open = false
						visible = false
						close_requested.emit()
						open_settings.emit()
				"Back":
					if confirm:
						if _sidestory_mode:
							_is_open = false
							visible = false
							close_requested.emit()
							sidestory_back_requested.emit()
						elif _restricted:
							close()
						else:
							_level = MenuLevel.MAIN
							_focus_idx = _find_option_index(_main_options, "System")
							_refresh_options()
				"Title":
					if confirm: _show_confirm()
		MenuLevel.SIDESTORY:
			var o := _sidestory_options[_focus_idx]
			if confirm:
				_is_open = false
				visible = false
				open_sidestory.emit(o.id)


# ===================================================================
# 输入
# ===================================================================

func _input(event: InputEvent) -> void:
	if not _is_open or not event.is_pressed(): return

	# ── 确认对话框输入接管 ──
	if _confirm_active:
		_handle_confirm_input(event)
		return

	if event.is_action_pressed("ui_cancel"):
		match _level:
			MenuLevel.SYSTEM:
				if _sidestory_mode or _restricted:
					close(); get_viewport().set_input_as_handled(); return
				_level = MenuLevel.MAIN
				_focus_idx = _find_option_index(_main_options, "System")
				_refresh_options(); _play_click(); get_viewport().set_input_as_handled(); return
			MenuLevel.SIDESTORY:
				_level = MenuLevel.MAIN
				_focus_idx = _find_option_index(_main_options, "Data")
				_refresh_options(); _play_click(); get_viewport().set_input_as_handled(); return
			MenuLevel.MAIN:    close(); get_viewport().set_input_as_handled(); return
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right"):
		_handle_action(1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_handle_action(-1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_entrance_focus_token += 1   # 取消入场焦点
		_focus_idx = max(0, _focus_idx - 1); _update_focus(); _play_click(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_entrance_focus_token += 1
		var sz := _get_current_options().size()
		_focus_idx = min(sz - 1, _focus_idx + 1); _update_focus(); _play_click(); get_viewport().set_input_as_handled()


# ===================================================================
# 辅助函数
# ===================================================================

func _play_click() -> void:
	AudioManager.play_click()


func _swallow_input(_event: InputEvent) -> void:
	pass  # 阻止所有输入传递到后面的视觉小说界面

func _kill_anim() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null
	for tw: Tween in _entry_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_entry_tweens.clear()


## 在选项列表中查找指定 id 的索引，未找到时返回最后一项的索引。
func _find_option_index(options: Array[Dictionary], target_id: String) -> int:
	for i: int in range(options.size()):
		if options[i].get("id", "") == target_id:
			return i
	return maxi(0, options.size() - 1)


# ===================================================================
# 返回标题确认对话框
# ===================================================================

func _build_confirm_dialog() -> void:
	# ── 额外暗化层（叠加在现有 DarkenBg 之上）──
	var confirm_dim := ColorRect.new()
	confirm_dim.name = "ConfirmDim"
	confirm_dim.color = Color(0, 0, 0, 0.3)
	confirm_dim.modulate.a = 0.0
	confirm_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_dim.gui_input.connect(_on_confirm_dim_clicked)
	add_child(confirm_dim)

	# ── 中央 Band（clip_contents 使子元素随 scaleX 自然裁剪）──
	var band := Control.new()
	_confirm_band = band
	band.name = "ConfirmBand"
	band.set_anchors_preset(Control.PRESET_FULL_RECT)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.clip_contents = true
	band.visible = false
	add_child(band)

	var band_bg := ColorRect.new()
	band_bg.name = "BandBg"
	band_bg.color = Color(0, 0, 0, 0.95)
	band_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	band_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(band_bg)

	var top_border := ColorRect.new()
	top_border.name = "TopBorder"
	top_border.color = Color(1, 1, 1, 0.2)
	top_border.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_border.offset_bottom = 2.0
	top_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(top_border)

	var bottom_border := ColorRect.new()
	bottom_border.name = "BottomBorder"
	bottom_border.color = Color(1, 1, 1, 0.2)
	bottom_border.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_border.offset_top = -2.0
	bottom_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(bottom_border)

	# ── 品牌框 "Confirm" + "确认" ──
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var branding := Control.new()
	branding.name = "ConfirmBranding"
	branding.position = Vector2(48, vp_h / 2.0 - BAND_PAD - 48)
	branding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(branding)

	var shadow := ColorRect.new()
	shadow.name = "Shadow"
	shadow.color = Color(1, 1, 1, 0.1)
	shadow.position = Vector2(10, 10)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	branding.add_child(shadow)

	var box_bg := ColorRect.new()
	box_bg.name = "BoxBg"
	box_bg.color = Color.WHITE
	box_bg.size = Vector2(260, 156)
	box_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	branding.add_child(box_bg)
	shadow.size = box_bg.size

	var en_title := Label.new()
	en_title.name = "EnTitle"
	en_title.text = "Confirm"
	en_title.add_theme_color_override("font_color", Color.BLACK)
	en_title.add_theme_font_size_override("font_size", 72)
	en_title.position = Vector2(14, 16)
	en_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_tcm: en_title.add_theme_font_override("font", GameManager.font_tcm)
	branding.add_child(en_title)

	var zh_title := Label.new()
	zh_title.name = "ZhTitle"
	zh_title.text = "" if GameManager.is_locale("en") else tr("确认")
	zh_title.add_theme_color_override("font_color", Color.BLACK)
	zh_title.add_theme_font_size_override("font_size", 32)
	zh_title.position = Vector2(20, 104)
	zh_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_zh_title: zh_title.add_theme_font_override("font", GameManager.font_zh_title)
	branding.add_child(zh_title)

	# ── 问题文本 ──
	var question := Label.new()
	question.name = "ConfirmQuestion"
	question.text = tr("是否退出？未保存的游戏将在退出后作废。")
	question.position = Vector2(48, vp_h - BAND_PAD - 48)
	question.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	question.add_theme_font_size_override("font_size", 28)
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_zh_body: question.add_theme_font_override("font", GameManager.font_zh_body)
	band.add_child(question)

	# ── 选项 VBoxContainer ──
	var opt_container := VBoxContainer.new()
	opt_container.name = "ConfirmOptions"
	opt_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var vp_w: float = get_viewport().get_visible_rect().size.x
	opt_container.position = Vector2(vp_w - 520, vp_h / 2.0 - OPTION_HEIGHT)
	opt_container.custom_minimum_size = Vector2(480, OPTION_HEIGHT * CONFIRM_OPTIONS.size())
	opt_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(opt_container)

	for i: int in range(CONFIRM_OPTIONS.size()):
		var data: Dictionary = CONFIRM_OPTIONS[i]
		var item: Control = _make_confirm_option(i, data)
		opt_container.add_child(item)
		_confirm_option_nodes.append(item)

	# 初始隐藏确认 UI（band 和 dim；band 子元素随之不可见）
	_confirm_band.visible = false
	confirm_dim.visible = false


func _make_confirm_option(index: int, data: Dictionary) -> Control:
	var container := Control.new()
	container.name = "ConfirmOption_" + str(index)
	container.custom_minimum_size = Vector2(480, OPTION_HEIGHT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var sweep := ColorRect.new()
	sweep.name = "Sweep"
	sweep.color = Color.WHITE
	sweep.size = Vector2(480, OPTION_HEIGHT)
	sweep.scale = Vector2(0, 1)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sweep)

	var hbox := HBoxContainer.new()
	hbox.name = "Content"
	hbox.size = Vector2(480, OPTION_HEIGHT)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(hbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	var title_label := Label.new()
	title_label.name = "Title"
	title_label.text = data.title
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_tcm: title_label.add_theme_font_override("font", GameManager.font_tcm)
	hbox.add_child(title_label)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(12, 0)
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer2)

	var zh_label := Label.new()
	zh_label.name = "ZhLabel"
	zh_label.text = "" if GameManager.is_locale("en") else tr(data.label)
	zh_label.add_theme_font_size_override("font_size", 24)
	zh_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_zh_title: zh_label.add_theme_font_override("font", GameManager.font_zh_title)
	hbox.add_child(zh_label)

	container.mouse_entered.connect(_on_confirm_option_hovered.bind(index))
	container.gui_input.connect(_on_confirm_option_clicked.bind(index))
	container.set_meta("sweep", sweep)
	container.set_meta("title_label", title_label)
	container.set_meta("zh_label", zh_label)

	return container


func _show_confirm() -> void:
	_confirm_active = true
	_confirm_sel = 1
	_confirm_interactive = false

	# ── 初始状态 ──
	# ConfirmDim（sibling）从透明开始，入场时淡入
	var confirm_dim := get_node_or_null("ConfirmDim") as ColorRect
	if confirm_dim:
		confirm_dim.modulate.a = 0.0
		confirm_dim.visible = true

	# Band 从右侧缩放到 0（pivot 在右边缘），子元素随之裁剪
	_confirm_band.pivot_offset.x = _confirm_band.size.x
	_confirm_band.scale.x = 0.0
	_confirm_band.visible = true

	# Branding 右移 + 透明（restore targets 在动画中反向 tween）
	var branding := _confirm_band.get_node_or_null("ConfirmBranding") as Control
	var brand_rest_x: float = branding.position.x if branding else 0.0
	if branding:
		branding.position.x += 50.0
		branding.modulate.a = 0.0

	# Question 右移 + 透明
	var question := _confirm_band.get_node_or_null("ConfirmQuestion") as Label
	var q_rest_x: float = question.position.x if question else 0.0
	if question:
		question.position.x += 50.0
		question.modulate.a = 0.0

	# Options 右移 + 透明
	for w: Control in _confirm_option_nodes:
		w.position.x = 100.0
		w.modulate.a = 0.0

	# Footer 透明
	var footer := _confirm_band.get_node_or_null("ConfirmFooter") as Label
	if footer:
		footer.modulate.a = 0.0

	# ── 阶段 1：Dim 淡入 + Band 展开（并行，0.35s）──
	var t_main := create_tween().set_parallel(true)
	t_main.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	if confirm_dim:
		t_main.tween_property(confirm_dim, "modulate:a", 1.0, 0.35)
	t_main.tween_property(_confirm_band, "scale:x", 1.0, 0.45).from(0.0)

	# ── 阶段 2：Branding 滑入（延迟 0.15s，0.45s）──
	if branding:
		var t_brand := create_tween().set_parallel(true)
		t_brand.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_brand.tween_property(branding, "position:x", brand_rest_x, 0.45).set_delay(0.15)
		t_brand.tween_property(branding, "modulate:a", 1.0, 0.45).set_delay(0.15)

	# ── 阶段 3：Question 滑入（延迟 0.25s，0.45s）──
	if question:
		var t_q := create_tween().set_parallel(true)
		t_q.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_q.tween_property(question, "position:x", q_rest_x, 0.45).set_delay(0.25)
		t_q.tween_property(question, "modulate:a", 1.0, 0.45).set_delay(0.25)

	# ── 阶段 4：Options 逐行错峰滑入（延迟 0.35 + i*0.08，0.4s）──
	for i: int in range(_confirm_option_nodes.size()):
		var w: Control = _confirm_option_nodes[i]
		var d: float = 0.35 + i * 0.08
		var ti := create_tween().set_parallel(true)
		ti.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		ti.tween_property(w, "position:x", 0.0, 0.4).set_delay(d)
		ti.tween_property(w, "modulate:a", 1.0, 0.4).set_delay(d)

	# ── 阶段 5：Footer 淡入（延迟 0.45s）──
	if footer:
		var t_ft := create_tween()
		t_ft.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_ft.tween_property(footer, "modulate:a", 1.0, 0.3).set_delay(0.45)

	# ── 收尾：应用焦点 → 启用交互 ──
	var t_final := create_tween()
	t_final.tween_callback(_update_confirm_focus).set_delay(0.52)
	t_final.tween_callback(_enable_confirm_interaction)


## 退场动画 — 入场的反向：元素按出场相反顺序逐级右滑 + 淡出
func _hide_confirm(on_done: Callable) -> void:
	_confirm_interactive = false

	# 立刻杀死焦点 tween，防止退出时焦点动画继续运行
	if _confirm_focus_tween and _confirm_focus_tween.is_valid():
		_confirm_focus_tween.kill()

	var confirm_dim := get_node_or_null("ConfirmDim") as ColorRect
	var branding := _confirm_band.get_node_or_null("ConfirmBranding") as Control
	var question := _confirm_band.get_node_or_null("ConfirmQuestion") as Label
	var footer := _confirm_band.get_node_or_null("ConfirmFooter") as Label

	# ── 阶段 1：Footer 先走（t=0，0.15s）──
	if footer:
		var t_ft := create_tween()
		t_ft.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		t_ft.tween_property(footer, "modulate:a", 0.0, 0.15)

	# ── 阶段 2：Options 逐行反向滑出（No→Yes，错峰 0.07s，0.25s）──
	for i: int in range(_confirm_option_nodes.size() - 1, -1, -1):
		var w: Control = _confirm_option_nodes[i]
		var d: float = 0.05 + (_confirm_option_nodes.size() - 1 - i) * 0.07
		var ti := create_tween().set_parallel(true)
		ti.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		ti.tween_property(w, "position:x", 80.0, 0.25).set_delay(d)
		ti.tween_property(w, "modulate:a", 0.0, 0.25).set_delay(d)

	# ── 阶段 3：Question 右滑 + 淡出（delay 0.20s，0.25s）──
	if question:
		var q_rest: float = question.position.x
		var t_q := create_tween().set_parallel(true)
		t_q.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		t_q.tween_property(question, "position:x", q_rest + 50.0, 0.25).set_delay(0.20)
		t_q.tween_property(question, "modulate:a", 0.0, 0.25).set_delay(0.20)

	# ── 阶段 4：Branding 右滑 + 淡出（delay 0.28s，0.25s）──
	if branding:
		var b_rest: float = branding.position.x
		var t_b := create_tween().set_parallel(true)
		t_b.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		t_b.tween_property(branding, "position:x", b_rest + 50.0, 0.25).set_delay(0.28)
		t_b.tween_property(branding, "modulate:a", 0.0, 0.25).set_delay(0.28)

	# ── 阶段 5：Band 收缩 + Dim 淡出（delay 0.36s，收束）──
	var t_close := create_tween().set_parallel(true)
	t_close.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	if confirm_dim:
		t_close.tween_property(confirm_dim, "modulate:a", 0.0, 0.2).set_delay(0.36)
	t_close.tween_property(_confirm_band, "scale:x", 0.0, 0.25).set_delay(0.36)
	t_close.tween_callback(_on_confirm_hidden).set_delay(0.36 + 0.25)
	t_close.tween_callback(on_done).set_delay(0.36 + 0.25)


func _on_confirm_hidden() -> void:
	_confirm_active = false
	_confirm_band.visible = false
	var confirm_dim := get_node_or_null("ConfirmDim") as ColorRect
	if confirm_dim:
		confirm_dim.visible = false

	# 重置退出动画中偏移的位置，确保下次入场从正确位置开始
	var branding := _confirm_band.get_node_or_null("ConfirmBranding") as Control
	if branding:
		branding.position.x -= 50.0
	var question := _confirm_band.get_node_or_null("ConfirmQuestion") as Label
	if question:
		question.position.x -= 50.0
	for w: Control in _confirm_option_nodes:
		w.position.x = 0.0


func _enable_confirm_interaction() -> void:
	_confirm_interactive = true


func _handle_confirm_input(event: InputEvent) -> void:
	if not _confirm_interactive:
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_confirm_sel = 0
		_update_confirm_focus()
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_confirm_sel = 1
		_update_confirm_focus()
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_play_click()
		if _confirm_sel == 0:
			_hide_confirm(_on_confirm_yes)
		else:
			_hide_confirm(_on_confirm_no)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_play_click()
		_hide_confirm(_on_confirm_no)
		get_viewport().set_input_as_handled()


func _update_confirm_focus() -> void:
	if _confirm_focus_tween and _confirm_focus_tween.is_valid():
		_confirm_focus_tween.kill()

	_confirm_focus_tween = create_tween().set_parallel(true)
	_confirm_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i: int in range(_confirm_option_nodes.size()):
		var child: Control = _confirm_option_nodes[i]
		var sweep: ColorRect = child.get_meta("sweep")
		var title: Label = child.get_meta("title_label")
		var zh: Label = child.get_meta("zh_label")
		var is_focused: bool = i == _confirm_sel

		_confirm_focus_tween.tween_property(sweep, "scale:x", 1.2 if is_focused else 0.0, 0.25)
		_confirm_focus_tween.tween_property(sweep, "position:x", -60.0 if is_focused else 0.0, 0.25)
		_confirm_focus_tween.tween_property(child, "modulate:a", 1.0 if is_focused else 0.4, 0.25)

		title.add_theme_color_override("font_color", Color.BLACK if is_focused else Color.WHITE)
		zh.add_theme_color_override("font_color", Color.BLACK if is_focused else Color(1, 1, 1, 0.8))


func _on_confirm_option_hovered(index: int) -> void:
	if not _confirm_interactive: return
	if _confirm_sel != index:
		_confirm_sel = index
		_update_confirm_focus()
		_play_click()


func _on_confirm_option_clicked(event: InputEvent, index: int) -> void:
	if not _confirm_interactive: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_play_click()
		if index == 0:
			_hide_confirm(_on_confirm_yes)
		else:
			_hide_confirm(_on_confirm_no)


func _on_confirm_dim_clicked(event: InputEvent) -> void:
	if not _confirm_interactive: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_play_click()
		_hide_confirm(_on_confirm_no)


func _on_confirm_yes() -> void:
	_is_open = false
	visible = false
	back_to_title.emit()


func _on_confirm_no() -> void:
	# 恢复 TabMenu SYSTEM 层焦点（默认选中 "Back 返回菜单"）
	_focus_idx = _find_option_index(_system_options, "Back")
	_update_focus()
