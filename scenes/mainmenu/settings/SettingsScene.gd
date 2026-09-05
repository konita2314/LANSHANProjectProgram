## SettingsScene : Control
## 设置/配置屏幕。左侧分类导航 + 右侧动态内容。
## 数据驱动 + 组件化（SettingsSliderRow / SettingsCycleRow / SettingsSectionHeader）。
## 支持本地化：切换语言时不重建节点，只 refresh。
extends Control

signal back_requested()

var _focus_idx: int = 0
var _disabled: bool = false
var _active_category: int = 0
var _is_first_enter: bool = true
var _categories: Array[Dictionary] = []
var _settings: AppSettings
var _row_nodes: Array[Control] = []        # Array[SettingsRow]
var _row_id_to_index: Dictionary = {}      # row_id -> row index in _row_nodes
var _sidebar_nodes: Array[Control] = []    # sidebar category buttons
var _back_bar: BackBar = null


@onready var _title_label: Label = %TitleLabel
@onready var _configs_container: VBoxContainer = %ConfigsContainer
@onready var _sidebar_list: VBoxContainer = %SidebarList
@warning_ignore("unused_private_class_variable")
@onready var _back_button: Control = %BackButton


func _ready() -> void:
	_settings = GameManager.get_settings()
	_build_categories()
	_build_sidebar()
	_show_category(0)
	_setup_back_button()
	_animate_enter()


# ── 数据 ─────────────────────────────────────────────────

func _build_categories() -> void:
	_categories = [
		{
			"id": "AUDIO", "label": "AUDIO", "zh": tr("音频"), "desc": tr("控制音频输出与音量大小"),
			"rows": [
				{"id": "master", "zh": tr("主音量"), "is_slider": true, "setting_key": "master_volume"},
				{"id": "bgm", "zh": tr("背景音乐音量"), "is_slider": true, "setting_key": "bgm_volume"},
				{"id": "ambience", "zh": tr("环境音音量"), "is_slider": true, "setting_key": "ambience_volume"},
				{"id": "sfx", "zh": tr("音效音量"), "is_slider": true, "setting_key": "sfx_volume"},
			]
		},
		{
			"id": "GAMEPLAY", "label": "GAMEPLAY", "zh": tr("游戏"), "desc": tr("控制剧情推进与交互行为"),
			"rows": [
				{"id": "text_speed", "zh": tr("文本滚动速度"), "is_slider": false,
					"setting_key": "text_speed",
					"options": ["slow", "normal", "fast"],
					"option_labels": {"slow": "慢", "normal": "中", "fast": "快"}},
				{"id": "auto_play", "zh": tr("自动剧情"), "is_slider": false,
					"setting_key": "auto_play",
					"options": [false, true],
					"option_labels": {"false": "关闭", "true": "开启"}},
			]
		},
		{
			"id": "SYSTEM", "label": "SYSTEM", "zh": tr("系统"), "desc": tr("显示与性能相关设置"),
			"rows": [
				{"id": "language", "zh": tr("界面语言"), "is_slider": false,
					"setting_key": "language",
					"options": ["ZH", "EN"],
					"option_labels": {"ZH": "简体中文", "EN": "ENGLISH"}, "is_language": true},
				{"id": "display_mode", "zh": tr("显示模式"), "is_slider": false,
					"setting_key": "display_mode",
					"options": ["windowed", "fullscreen"],
					"option_labels": {"windowed": "窗口", "fullscreen": "全屏"}, "has_display_side_effect": true},
				{"id": "quality", "zh": tr("性能模式"), "is_slider": false,
					"setting_key": "quality",
					"options": ["low", "high"],
					"option_labels": {"low": "开启", "high": "关闭"}},
				{"id": "framerate", "zh": tr("帧率"), "is_slider": false,
					"setting_key": "framerate",
					"options": ["fps30", "fps60", "fps120", "fps240", "vsync", "unlimited"],
					"option_labels": {"fps30": "30 FPS", "fps60": "60 FPS", "fps120": "120 FPS",
						"fps240": "240 FPS", "vsync": "垂直同步", "unlimited": "帧率无上限"}},
			]
		},
	]

	_title_label.text = "Config"
	_title_label.add_theme_font_size_override("font_size", 72)
	if GameManager.font_tcm: _title_label.add_theme_font_override("font", GameManager.font_tcm)


# ── 侧边栏 ───────────────────────────────────────────────

func _build_sidebar() -> void:
	_sidebar_nodes.clear()
	for i: int in range(_categories.size()):
		var cat: Dictionary = _categories[i]
		var btn := _create_sidebar_button(cat, i)
		_sidebar_list.add_child(btn)
		_sidebar_nodes.append(btn)


func _create_sidebar_button(cat: Dictionary, idx: int) -> Control:
	var btn := Control.new()
	btn.name = "CatBtn_" + cat.id
	btn.custom_minimum_size = Vector2(0, 64)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	# Sweep
	var sweep := ColorRect.new()
	sweep.name = "Sweep"
	sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	sweep.color = Color(1, 1, 1, 0.0)
	sweep.scale = Vector2(0, 1)
	sweep.pivot_offset = Vector2(0, 0)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sweep)

	# Left indicator bar
	var bar := ColorRect.new()
	bar.name = "LeftBar"
	bar.size = Vector2(3, 0)
	bar.position = Vector2(0, 0)
	bar.color = Color.WHITE
	bar.modulate.a = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bar)

	# English label
	var en_label := Label.new()
	en_label.name = "EnLabel"
	en_label.position = Vector2(24, 12)
	en_label.text = cat.label
	en_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	en_label.add_theme_font_size_override("font_size", 20)
	en_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_tcm: en_label.add_theme_font_override("font", GameManager.font_tcm)
	btn.add_child(en_label)

	# Chinese label (hidden in EN mode)
	var zh_label := Label.new()
	zh_label.name = "ZhLabel"
	zh_label.position = Vector2(24, 38)
	zh_label.text = cat.zh
	zh_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	zh_label.add_theme_font_size_override("font_size", 16)
	zh_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager.font_zh_title: zh_label.add_theme_font_override("font", GameManager.font_zh_title)
	zh_label.visible = not GameManager.is_locale("en")
	btn.add_child(zh_label)

	btn.mouse_entered.connect(_on_sidebar_hovered.bind(idx))
	_update_sidebar_button_state(btn, idx)

	return btn


func _on_sidebar_hovered(idx: int) -> void:
	if _disabled or _active_category == idx: return
	_show_category(idx)
	_play_click()


func _update_sidebar_focus() -> void:
	for i: int in range(_sidebar_nodes.size()):
		_update_sidebar_button_state(_sidebar_nodes[i], i)


func _update_sidebar_button_state(btn: Control, idx: int) -> void:
	var active: bool = idx == _active_category
	var sweep: ColorRect = btn.get_node("Sweep") as ColorRect
	var bar: ColorRect = btn.get_node("LeftBar") as ColorRect
	var en_label: Label = btn.get_node("EnLabel") as Label

	en_label.add_theme_color_override("font_color", Color.WHITE if active else Color(1, 1, 1, 0.4))

	if active:
		_kill_sidebar_tween(btn)
		sweep.color.a = 0.18
		var tw := create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(sweep, "scale:x", 1.0, 0.22)
		tw.tween_property(sweep, "color:a", 0.06, 0.32)
		tw.tween_property(bar, "modulate:a", 0.6, 0.25)
		btn.set_meta("sb_tween", tw)
	else:
		_kill_sidebar_tween(btn)
		var tw := create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tw.tween_property(sweep, "scale:x", 0.0, 0.20)
		tw.tween_property(sweep, "color:a", 0.0, 0.20)
		tw.tween_property(bar, "modulate:a", 0.0, 0.20)
		btn.set_meta("sb_tween", tw)


func _kill_sidebar_tween(btn: Control) -> void:
	if not btn.has_meta("sb_tween"): return
	var old: Tween = btn.get_meta("sb_tween")
	if old and old.is_valid():
		old.kill()


# ── 分类切换（动态实例化）────────────────────────────────

func _show_category(idx: int) -> void:
	_active_category = idx
	_clear_panel()
	_populate_panel()
	_focus_idx = 0
	_update_row_focus()
	_update_sidebar_focus()


func _clear_panel() -> void:
	for child in _configs_container.get_children():
		child.queue_free()
	_row_nodes.clear()
	_row_id_to_index.clear()


func _populate_panel() -> void:
	var cat: Dictionary = _categories[_active_category]

	for row_data: Dictionary in cat.rows:
		var row: Control = _create_config_row(row_data)
		_configs_container.add_child(row)
		_row_nodes.append(row)
		_row_id_to_index[row_data.id] = _row_nodes.size() - 1


func _create_config_row(cfg: Dictionary) -> Control:
	if cfg.is_slider:
		@warning_ignore("confusable_local_declaration")
		var row := SettingsSliderRow.new()
		var initial_val: float = _settings.get_prop(cfg.setting_key) as float
		row.configure(cfg.id, cfg.zh, initial_val, cfg.setting_key)
		row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.value_changed.connect(_on_slider_value_changed)
		row.hovered.connect(_on_row_hovered_by_id)
		return row

	var row := SettingsCycleRow.new()
	row.configure(cfg.id, cfg.zh, _get_option_display(cfg.id))
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.stepped.connect(_on_step_option)
	row.hovered.connect(_on_row_hovered_by_id)
	return row


# ── 数据查找辅助 ──────────────────────────────────────────

func _find_row_config(row_id: String) -> Dictionary:
	for cat: Dictionary in _categories:
		for row: Dictionary in cat.rows:
			if row.id == row_id:
				return row
	return {}


func _get_current_rows() -> Array[Dictionary]:
	if _active_category < 0 or _active_category >= _categories.size():
		return []
	var rows: Array[Dictionary] = []
	rows.assign(_categories[_active_category].rows)
	return rows


# ── 值读取 ────────────────────────────────────────────────

func _get_option_display(id: String) -> String:
	var cfg := _find_row_config(id)
	if cfg.is_empty(): return ""

	if cfg.get("is_language", false):
		var loc: String = GameManager.get_locale()
		var label: String = GameManager.LOCALE_LABELS.get(loc, "ENGLISH")
		return tr(label)

	var current_value: Variant = _settings.get_prop(cfg.setting_key)
	var labels: Dictionary = cfg.get("option_labels", {})
	var lookup_key: String = str(current_value).to_lower()
	var raw: String = labels.get(lookup_key, "")
	if raw.is_empty():
		raw = labels.get(current_value, str(current_value))
	return tr(raw)


# ── 信号处理 ──────────────────────────────────────────────

func _on_slider_value_changed(value: float, row_id: String) -> void:
	var cfg := _find_row_config(row_id)
	if cfg.is_empty(): return
	GameManager.set_setting(cfg.setting_key, value)
	AudioManager.apply_volumes()


func _on_step_option(id: String, dir: int) -> void:
	_play_click()

	var cfg := _find_row_config(id)
	if cfg.is_empty(): return

	var opts: Array = cfg.options
	var current_value: Variant = _settings.get_prop(cfg.setting_key)
	var cur: int = opts.find(current_value)
	var next_val: Variant = opts[(cur + dir + opts.size()) % opts.size()]

	GameManager.set_setting(cfg.setting_key, next_val)
	_settings = GameManager.get_settings()

	if cfg.get("has_display_side_effect", false):
		_apply_display_mode(next_val)
	elif cfg.get("is_language", false):
		_on_language_changed()

	_update_display_values()


func _apply_display_mode(mode: String) -> void:
	if mode == "fullscreen":
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_row_hovered_by_id(row_id: String) -> void:
	var idx: int = _row_id_to_index.get(row_id, -1)
	if idx >= 0:
		_on_row_hovered(idx)


# ── 语言切换：不重建节点，只 refresh ─────────────────────

func _on_language_changed() -> void:
	_build_categories()
	_update_row_labels()
	_update_display_values()
	_update_sidebar_texts()
	if _back_bar:
		_back_bar.set_language()


func _update_row_labels() -> void:
	var rows: Array[Dictionary] = _get_current_rows()
	for i: int in range(_row_nodes.size()):
		if i >= rows.size(): break
		var row: SettingsRow = _row_nodes[i] as SettingsRow
		row.refresh_locale(rows[i])


func _update_display_values() -> void:
	var rows: Array[Dictionary] = _get_current_rows()
	for i: int in range(_row_nodes.size()):
		if i >= rows.size(): break
		var ctrl: Control = _row_nodes[i]
		if ctrl is SettingsSliderRow: continue
		var srow: SettingsRow = ctrl as SettingsRow
		srow.refresh_value(_settings, _get_option_display(rows[i].id))


func _update_sidebar_texts() -> void:
	var is_en: bool = GameManager.is_locale("en")
	for i: int in range(_sidebar_nodes.size()):
		var btn: Control = _sidebar_nodes[i]
		var cat: Dictionary = _categories[i]
		var zh_label: Label = btn.get_node("ZhLabel") as Label
		zh_label.text = cat.zh
		zh_label.visible = not is_en


# ── Sweep 聚焦动画 ────────────────────────────────────────

func _update_row_focus() -> void:
	for i: int in range(_row_nodes.size()):
		var row: Control = _row_nodes[i]
		var is_focused: bool = i == _focus_idx
		if is_focused:
			_animate_row_select(row)
		else:
			_animate_row_deselect(row)

		var primary: Label = row.get_node_or_null("PrimaryLabel") as Label
		if primary:
			primary.add_theme_color_override("font_color", Color.WHITE if is_focused else Color(1, 1, 1, 0.6))

		if row is SettingsCycleRow:
			var val_label: Label = row.get_node_or_null("ContentRow/ValLabel") as Label
			if val_label:
				val_label.add_theme_color_override("font_color", Color.WHITE if is_focused else Color(1, 1, 1, 0.8))


func _animate_row_select(row: Control) -> void:
	var sweep: ColorRect = row.get_node_or_null("Sweep") as ColorRect
	if not sweep: return
	_kill_row_tween(row)
	sweep.color.a = 0.18
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(sweep, "scale:x", 1.0, 0.22)
	tw.tween_property(sweep, "color:a", 0.08, 0.32)
	row.set_meta("row_tween", tw)


func _animate_row_deselect(row: Control) -> void:
	var sweep: ColorRect = row.get_node_or_null("Sweep") as ColorRect
	if not sweep: return
	_kill_row_tween(row)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(sweep, "scale:x", 0.0, 0.20)
	tw.tween_property(sweep, "color:a", 0.0, 0.20)
	row.set_meta("row_tween", tw)


func _kill_row_tween(row: Control) -> void:
	if not row.has_meta("row_tween"): return
	var old: Tween = row.get_meta("row_tween")
	if old and old.is_valid():
		old.kill()


# ── 焦点与导航 ────────────────────────────────────────────

func _on_row_hovered(index: int) -> void:
	if _disabled or _focus_idx == index: return
	_focus_idx = index
	_update_row_focus()
	_play_click()


func _setup_back_button() -> void:
	_back_bar = BackBar.attach(self, _on_back_pressed)


func _on_back_pressed() -> void:
	back_requested.emit()


func _play_click() -> void:
	AudioManager.play_click()


func _animate_enter() -> void:
	# 基础淡入，与其他场景的 GameManager.animate_scene_enter 风格一致
	_title_label.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title_label, "modulate:a", 1.0, 0.4)


# ── SceneManager 生命周期 ──────────────────────────────────

func _on_exit() -> void:
	_disabled = true


func _on_enter() -> void:
	_disabled = false
	if _is_first_enter:
		_is_first_enter = false
		_animate_first_entrance()
	else:
		_update_row_focus()


func _animate_first_entrance() -> void:
	# Title — fade in only，不修改 position（与其他场景一致）
	_title_label.modulate.a = 0.0
	var t_title := create_tween()
	t_title.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t_title.tween_property(_title_label, "modulate:a", 1.0, 0.4)

	# Sidebar buttons — stagger 0.06s each
	for i: int in range(_sidebar_nodes.size()):
		var btn: Control = _sidebar_nodes[i]
		btn.modulate.a = 0.0
		btn.position.x -= 15.0
		var t := create_tween().set_parallel(true)
		t.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(i * 0.06)
		t.tween_property(btn, "position:x", btn.position.x + 15.0, 0.3).set_delay(i * 0.06)

	# Rows — stagger min(index, 8) * 0.03s
	for i: int in range(_row_nodes.size()):
		var row: Control = _row_nodes[i]
		row.modulate.a = 0.0
		var delay: float = mini(i, 8) * 0.03 + 0.12
		var t := create_tween()
		t.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_property(row, "modulate:a", 1.0, 0.25).set_delay(delay)

	_update_row_focus()


func _input(event: InputEvent) -> void:
	if _disabled or not event.is_pressed(): return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_page_up"):
		if _focus_idx == 0 and _active_category > 0:
			_show_category(_active_category - 1)
			_focus_idx = _row_nodes.size() - 1
			_update_row_focus()
		else:
			_focus_idx = max(0, _focus_idx - 1)
			_update_row_focus()
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_page_down"):
		if _focus_idx >= _row_nodes.size() - 1 and _active_category < _categories.size() - 1:
			_show_category(_active_category + 1)
			_focus_idx = 0
			_update_row_focus()
		else:
			_focus_idx = min(_row_nodes.size() - 1, _focus_idx + 1)
			_update_row_focus()
		_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		if not _row_nodes.is_empty():
			var cfg := _find_row_config_by_index(_focus_idx)
			var row: SettingsRow = _row_nodes[_focus_idx] as SettingsRow
			if not cfg.is_empty() and cfg.is_slider:
				row.step_value(-0.05)
			else:
				row.step_value(-1.0)
			_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		if not _row_nodes.is_empty():
			var cfg := _find_row_config_by_index(_focus_idx)
			var row: SettingsRow = _row_nodes[_focus_idx] as SettingsRow
			if not cfg.is_empty() and cfg.is_slider:
				row.step_value(0.05)
			else:
				row.step_value(1.0)
			_play_click()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _find_row_config_by_index(idx: int) -> Dictionary:
	var rows: Array[Dictionary] = _get_current_rows()
	if idx < 0 or idx >= rows.size(): return {}
	return rows[idx]


func set_disabled(val: bool) -> void:
	_disabled = val
