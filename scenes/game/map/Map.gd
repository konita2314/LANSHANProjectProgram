## Map : Control
## 学校地图页面。全部 UI 节点在代码中构建。
##   鼠标拖拽 → 平移 / 滚轮 → 缩放 / WASD → 切换地点
extends Control

signal back_requested()
signal goto_location_requested(location_name: String)

# ---------------------------------------------------------------------------
# 地点数据 — 上移至 scripts/resources/MapData.gd（地点系统共享：@locate / API 校验）
# ---------------------------------------------------------------------------
const LOCATIONS: Array[Dictionary] = MapData.LOCATIONS

const MAP_W: float = 1672.0
const MAP_H: float = 941.0
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 1.12
const KEYBOARD_ZOOM: float = 2.0
const PANEL_SHIFT: float = 80.0
const DOT_SIZE: float = 14.0
const LABEL_OFFSET_X: float = 16.0
const LABEL_OFFSET_Y: float = -5.0
const DRAG_THRESHOLD: float = 4.0
const SCROLL_MARGIN: float = 100.0
const GOTO_REST_ALPHA: float = 0.75
const STAGGER_OFFSET: float = 50.0

# ---------------------------------------------------------------------------
# 状态
# ---------------------------------------------------------------------------
var _disabled: bool = false
var _menu_active: bool = false
var _can_go_back: bool = true
var _esc_blocked: bool = false
var _selected_idx: int = 0
var _last_selected_idx: int = -1
var _marker_nodes: Array[Control] = []
var _zoom_level: float = 1.0
var _zoom_min: float = 1.0
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _pan_start: Vector2 = Vector2.ZERO
var _pan_tween: Tween = null
var _zoom_tween: Tween = null
var _panel_tween: Tween = null
var _map_shift_tween: Tween = null
var _goto_wrap: Panel = null
var _goto_sweep: ColorRect = null
var _goto_border_style: StyleBoxFlat = null
var _goto_rest_x: float = 0.0
var _goto_hover_tween: Tween = null
var _goto_enabled: bool = false

# ---------------------------------------------------------------------------
# 字体
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# UI 节点 — 静态节点在 Map.tscn 中，代码通过 @onready 引用
# ---------------------------------------------------------------------------
@onready var _title_label: Label = $TitleLabel
@onready var _subtitle_label: Label = $SubtitleLabel
@onready var _map_clip: Control = $MapClip
@onready var _map_container: Control = $MapClip/MapContainer
@onready var _info_panel: Control = $InfoPanel
@onready var _info_name: Label = $InfoPanel/NameLabel
@onready var _info_desc: Label = $InfoPanel/DescLabel
@onready var _info_suggest: Label = $InfoPanel/SuggestLabel
@onready var _info_border: ColorRect = $InfoPanel/BorderBot
@onready var _goto_label: Label = $InfoPanel/Goto
var _back_bar: BackBar = null


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:

	# 字幕标签 — 文本和可见性在运行时确定
	_subtitle_label.text = tr("校园地图")
	if GameManager.is_locale("en"):
		_subtitle_label.visible = false

	# 应用字体到场景中的静态标签
	if GameManager.font_tcm:
		_title_label.add_theme_font_override("font", GameManager.font_tcm)
		_info_name.add_theme_font_override("font", GameManager.font_tcm)
	if GameManager.font_zh_title:
		_subtitle_label.add_theme_font_override("font", GameManager.font_zh_title)
	if GameManager.font_zh_body:
		_info_desc.add_theme_font_override("font", GameManager.font_zh_body)

	_build_markers()
	_build_goto()
	_build_back_bar()
	_map_clip.gui_input.connect(_on_map_clip_input)
	# 注意：不在此管理 AudioManager.set_menu_mode —— Map 作为 Tab 菜单的
	# 子页面，音频模糊归 SceneManager 路由（MAP_FROM_VN）与 Tab 菜单
	# 生命周期统一管理（与 SettingsScene 同一模式），否则返回 Tab 时
	# _on_exit 会错误解除 Tab 菜单仍需要的低通滤波。





# ===================================================================
# 地点标记
# ===================================================================

func _build_markers() -> void:
	for i: int in range(LOCATIONS.size()):
		var loc: Dictionary = LOCATIONS[i]
		var marker: Control = _create_marker(i, loc)
		_map_container.add_child(marker)
		_marker_nodes.append(marker)


func _create_marker(idx: int, data: Dictionary) -> Control:
	var ctrl: Control = Control.new()
	ctrl.name = "Marker_" + str(idx)
	ctrl.position = Vector2(data.x - DOT_SIZE / 2.0, data.y - DOT_SIZE / 2.0)
	ctrl.size = Vector2(DOT_SIZE + LABEL_OFFSET_X + 120.0, maxf(DOT_SIZE, 22.0))
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	ctrl.mouse_default_cursor_shape = 2

	# 圆点
	var dot: ColorRect = ColorRect.new()
	dot.name = "Dot"
	dot.size = Vector2(DOT_SIZE, DOT_SIZE)
	dot.color = Color.BLACK
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(dot)

	# 名称标签 — 黑色 + 白色描边
	var lbl: Label = Label.new()
	lbl.name = "Label"
	lbl.text = data.name
	lbl.position = Vector2(LABEL_OFFSET_X, LABEL_OFFSET_Y)
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.7))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	@warning_ignore("static_called_on_instance")
	var f: Font = GameManager.select_font(lbl.text, GameManager.font_zh_title, GameManager.font_tcm)
	if f: lbl.add_theme_font_override("font", f)
	ctrl.add_child(lbl)

	ctrl.gui_input.connect(_on_marker_input.bind(idx))
	ctrl.set_meta("dot", dot)
	ctrl.set_meta("label", lbl)
	return ctrl



# ===================================================================
# 底部返回栏
# ===================================================================

func _build_back_bar() -> void:
	_back_bar = BackBar.attach(self, _on_back_pressed)


# ===================================================================
# Goto 按钮 — 包装器 + sweep 动画（参照 Notebook GotoNext）
# ===================================================================

func _build_goto() -> void:
	var parent: Node = _goto_label.get_parent()

	_goto_wrap = Panel.new()
	_goto_wrap.name = "GotoWrap"
	_goto_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	_goto_wrap.clip_contents = true

	_goto_wrap.anchor_left = _goto_label.anchor_left
	_goto_wrap.anchor_top = _goto_label.anchor_top
	_goto_wrap.anchor_right = _goto_label.anchor_right
	_goto_wrap.anchor_bottom = _goto_label.anchor_bottom
	_goto_wrap.offset_left = _goto_label.offset_left
	_goto_wrap.offset_top = _goto_label.offset_top
	_goto_wrap.offset_right = _goto_label.offset_right
	_goto_wrap.offset_bottom = _goto_label.offset_bottom

	_goto_border_style = StyleBoxFlat.new()
	_goto_border_style.bg_color = Color(0, 0, 0, 0)
	_goto_border_style.border_width_left = 1
	_goto_border_style.border_width_right = 1
	_goto_border_style.border_width_top = 1
	_goto_border_style.border_width_bottom = 1
	_goto_border_style.border_color = Color(1, 1, 1, 0.3)
	_goto_wrap.add_theme_stylebox_override("panel", _goto_border_style)

	parent.remove_child(_goto_label)
	parent.add_child(_goto_wrap)

	_goto_sweep = ColorRect.new()
	_goto_sweep.name = "Sweep"
	_goto_sweep.color = Color.WHITE
	_goto_sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goto_sweep.scale.x = 0.0
	_goto_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goto_wrap.add_child(_goto_sweep)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goto_wrap.add_child(hb)

	_goto_label.add_theme_font_size_override("font_size", 24)
	_goto_label.add_theme_color_override("font_color", Color.WHITE)
	_goto_label.visible = true
	hb.add_child(_goto_label)

	@warning_ignore("static_called_on_instance")
	var goto_font: Font = GameManager.select_font(_goto_label.text, GameManager.font_zh_title, GameManager.font_tcm)
	if goto_font:
		_goto_label.add_theme_font_override("font", goto_font)

	_goto_rest_x = _goto_wrap.position.x

	_goto_wrap.mouse_entered.connect(_on_goto_hover.bind(true))
	_goto_wrap.mouse_exited.connect(_on_goto_hover.bind(false))
	_goto_wrap.gui_input.connect(_on_goto_click)

	# 初始隐藏 — 由 set_goto_enabled() 或 _show_info_panel() 控制可见性
	_goto_wrap.position.x = _goto_rest_x + STAGGER_OFFSET
	_goto_wrap.modulate.a = 0.0
	_goto_wrap.visible = false


func _on_goto_hover(hovered: bool) -> void:
	if not _goto_enabled or not _info_panel.visible:
		return

	if _goto_hover_tween and _goto_hover_tween.is_valid():
		_goto_hover_tween.kill()

	_goto_hover_tween = create_tween().set_parallel(true)
	_goto_hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_goto_hover_tween.tween_property(_goto_sweep, "scale:x", 1.0 if hovered else 0.0, 0.25)
	_goto_hover_tween.tween_property(_goto_wrap, "position:x", _goto_rest_x - 50.0 if hovered else _goto_rest_x + 10.0, 0.25)
	_goto_hover_tween.tween_property(_goto_wrap, "modulate:a", 1.0 if hovered else GOTO_REST_ALPHA, 0.25)

	_goto_label.add_theme_color_override("font_color", Color.BLACK if hovered else Color.WHITE)
	@warning_ignore("incompatible_ternary")
	_goto_wrap.add_theme_stylebox_override("panel", _goto_border_style if not hovered else StyleBoxEmpty.new())


func _on_goto_click(event: InputEvent) -> void:
	if not _goto_enabled or not _info_panel.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _selected_idx < 0 or _selected_idx >= LOCATIONS.size():
			return
		AudioManager.play_click()
		goto_location_requested.emit(LOCATIONS[_selected_idx].name)
		# 地点系统："前往" = 显式操作，经 API 写入当前地点（浏览/选择不回写）
		GameManager.set_current_location(LOCATIONS[_selected_idx].name)


func set_goto_enabled(enabled: bool) -> void:
	_goto_enabled = enabled
	if not _goto_enabled:
		# 立即隐藏
		if _goto_hover_tween and _goto_hover_tween.is_valid():
			_goto_hover_tween.kill()
		_goto_wrap.visible = false
		_goto_wrap.position.x = _goto_rest_x + STAGGER_OFFSET
		_goto_wrap.modulate.a = 0.0
		_goto_sweep.scale.x = 0.0
	elif _info_panel.visible:
		# 面板已显示 → 立即动画入场
		_goto_wrap.position.x = _goto_rest_x + STAGGER_OFFSET
		_goto_wrap.modulate.a = 0.0
		_goto_wrap.visible = true
		var t_goto := create_tween().set_parallel(true)
		t_goto.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_goto.tween_property(_goto_wrap, "position:x", _goto_rest_x, 0.5)
		t_goto.tween_property(_goto_wrap, "modulate:a", GOTO_REST_ALPHA, 0.5)


# ===================================================================
# 选中 / 取消选中
# ===================================================================

func _select_location(idx: int, show_info: bool = false) -> void:
	if idx < 0 or idx >= LOCATIONS.size() or _marker_nodes.size() == 0:
		return

	var same_location: bool = (idx == _selected_idx)

	if _selected_idx >= 0 and not same_location and _selected_idx < _marker_nodes.size():
		var prev: Control = _marker_nodes[_selected_idx]
		var prev_dot: ColorRect = prev.get_meta("dot")
		prev_dot.color = Color.BLACK

	_selected_idx = idx
	_last_selected_idx = idx

	var marker: Control = _marker_nodes[idx]
	var dot: ColorRect = marker.get_meta("dot")
	dot.color = Color.RED

	if show_info and not (same_location and _info_panel.visible):
		_update_info_panel(idx)
	_scroll_to_location(idx)


func _deselect_location() -> void:
	if _selected_idx < 0:
		return
	var marker: Control = _marker_nodes[_selected_idx]
	var dot: ColorRect = marker.get_meta("dot")
	dot.color = Color.BLACK
	_selected_idx = -1
	var was_panel_visible: bool = _info_panel.visible
	_hide_info_panel()
	# 缩小回初始缩放比例 — 同时平移保持在边界内
	var old_zoom: float = _zoom_level
	_zoom_level = _zoom_min
	var clip_size: Vector2 = _map_clip.size
	if clip_size.x > 0 and clip_size.y > 0:
		# 保持当前画面中心不变，但遵守新的边界约束
		var world_center: Vector2 = (clip_size / 2.0 - _map_container.position) / old_zoom
		var target: Vector2 = clip_size / 2.0 - world_center * _zoom_min
		target = _guard_pan_bounds(target)
		# 面板隐藏后地图右移，填补右侧空出的区域
		if was_panel_visible:
			target.x += PANEL_SHIFT
			target = _guard_pan_bounds(target)
		_animate_pan(target)
	_animate_zoom(old_zoom, _zoom_min)


# ===================================================================
# 信息面板
# ===================================================================

func _update_info_panel(idx: int) -> void:
	var data: Dictionary = LOCATIONS[idx]
	_info_name.text = data.name
	@warning_ignore("static_called_on_instance")
	var nf: Font = GameManager.select_font(_info_name.text, GameManager.font_zh_title, GameManager.font_tcm)
	if nf: _info_name.add_theme_font_override("font", nf)
	# 白色背景 + 黑色文字 + 阴影（匹配 ESC 菜单品牌框风格）
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(8, 6)
	sb.shadow_color = Color(1, 1, 1, 0.1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_info_name.add_theme_color_override("font_color", Color.BLACK)
	_info_name.add_theme_stylebox_override("normal", sb)

	_info_desc.text = data.description
	@warning_ignore("static_called_on_instance")
	var df: Font = GameManager.select_font(_info_desc.text, GameManager.font_zh_body, GameManager.font_en_body)
	if df: _info_desc.add_theme_font_override("font", df)
	_info_desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))

	if not _info_panel.visible:
		_show_info_panel()


func _show_info_panel() -> void:
	# 提升到最上层 — 覆盖地图标记和标题
	_info_panel.z_index = 10

	# 已经显示中 → 只更新内容，不重播动画
	if _info_panel.visible:
		return

	# 面板从右侧滑入（只动画面板自身，不碰地图位移）
	var vp_w: float = get_viewport().get_visible_rect().size.x

	_info_panel.offset_left = vp_w
	_info_panel.offset_right = vp_w
	_info_panel.modulate.a = 1.0
	_info_panel.visible = true

	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()

	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(_info_panel, "offset_left", 0.0, 0.35)
	_panel_tween.tween_property(_info_panel, "offset_right", 0.0, 0.35)

	# ── 内部元素逐级入场（对齐 QuitModal 模式：右侧滑入 + 淡入）──

	# BorderBot — 分割线横向展开
	_info_border.scale = Vector2(0.0, 1.0)
	var t_border := create_tween()
	t_border.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_border.tween_property(_info_border, "scale:x", 1.0, 0.5).set_delay(0.12)

	# NameLabel — 右侧滑入 + 淡入
	var name_target_x: float = _info_name.position.x
	_info_name.position.x += 50.0
	_info_name.modulate.a = 0.0
	var t_name := create_tween().set_parallel(true)
	t_name.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_name.tween_property(_info_name, "position:x", name_target_x, 0.5).set_delay(0.20)
	t_name.tween_property(_info_name, "modulate:a", 1.0, 0.5).set_delay(0.20)

	# DescLabel — 右侧滑入 + 淡入
	var desc_target_x: float = _info_desc.position.x
	_info_desc.position.x += 50.0
	_info_desc.modulate.a = 0.0
	var t_desc := create_tween().set_parallel(true)
	t_desc.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_desc.tween_property(_info_desc, "position:x", desc_target_x, 0.5).set_delay(0.28)
	t_desc.tween_property(_info_desc, "modulate:a", 1.0, 0.5).set_delay(0.28)

	# SuggestLabel — 右侧滑入 + 淡入
	var suggest_target_x: float = _info_suggest.position.x
	_info_suggest.position.x += 50.0
	_info_suggest.modulate.a = 0.0
	var t_suggest := create_tween().set_parallel(true)
	t_suggest.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_suggest.tween_property(_info_suggest, "position:x", suggest_target_x, 0.5).set_delay(0.36)
	t_suggest.tween_property(_info_suggest, "modulate:a", 1.0, 0.5).set_delay(0.36)

	# Goto 按钮 — 仅在启用时跟随入场（参照 Notebook 内容元素动画）
	if _goto_enabled:
		_goto_wrap.position.x = _goto_rest_x + STAGGER_OFFSET
		_goto_wrap.modulate.a = 0.0
		_goto_wrap.visible = true
		var t_goto := create_tween().set_parallel(true)
		t_goto.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_goto.tween_property(_goto_wrap, "position:x", _goto_rest_x, 0.5).set_delay(0.44)
		t_goto.tween_property(_goto_wrap, "modulate:a", GOTO_REST_ALPHA, 0.5).set_delay(0.44)

func _hide_info_panel() -> void:
	# 面板已隐藏 → 无操作，防止重复位移
	if not _info_panel.visible:
		return

	# 面板向右滑出
	var vp_w: float = get_viewport().get_visible_rect().size.x

	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()

	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_panel_tween.tween_property(_info_panel, "offset_left", vp_w, 0.3)
	_panel_tween.tween_property(_info_panel, "offset_right", vp_w, 0.3)
	_panel_tween.chain().tween_callback(_on_panel_hidden)

	# 地图右移，填补面板退出后右侧空出的区域
	if _map_shift_tween and _map_shift_tween.is_valid():
		_map_shift_tween.kill()
	_map_shift_tween = create_tween()
	_map_shift_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# Guard: 确保位移后不会在左侧留下黑边（position.x > 0 则地图左缘露在 clip 内）
	var shift_target: Vector2 = _guard_pan_bounds(Vector2(_map_container.position.x + PANEL_SHIFT, _map_container.position.y))
	_map_shift_tween.tween_property(_map_container, "position:x", shift_target.x, 0.3)

	# 降回默认层级，避免遮挡其他 UI
	_info_panel.z_index = 0



func _on_panel_hidden() -> void:
	_info_panel.visible = false
	# 重置 Goto 按钮位置，为下次入场动画做准备
	if _goto_wrap:
		if _goto_hover_tween and _goto_hover_tween.is_valid():
			_goto_hover_tween.kill()
		_goto_wrap.position.x = _goto_rest_x + STAGGER_OFFSET
		_goto_wrap.modulate.a = 0.0
		_goto_wrap.visible = false
		_goto_sweep.scale.x = 0.0
		_goto_label.add_theme_color_override("font_color", Color.WHITE)
		_goto_wrap.add_theme_stylebox_override("panel", _goto_border_style)


# ===================================================================
# 自动滚动
# ===================================================================

func _clamp_pan() -> void:
	var clip_size: Vector2 = _map_clip.size
	var map_w: float = MAP_W * _zoom_level
	var map_h: float = MAP_H * _zoom_level
	var min_x: float = clip_size.x - map_w
	var min_y: float = clip_size.y - map_h
	_map_container.position.x = clampf(_map_container.position.x, min_x, 0.0)
	_map_container.position.y = clampf(_map_container.position.y, min_y, 0.0)


func _center_on_location(idx: int) -> void:
	var data: Dictionary = LOCATIONS[idx]
	var loc_center: Vector2 = Vector2(data.x, data.y)
	var clip_size: Vector2 = _map_clip.size
	if clip_size.x <= 0 or clip_size.y <= 0:
		return

	# 更新缩放并计算居中位置（用目标缩放来算边界）
	var old_zoom: float = _zoom_level
	_zoom_level = KEYBOARD_ZOOM

	# 尽量居中该地点，但不超出图片边界
	var target: Vector2 = clip_size / 2.0 - loc_center * _zoom_level
	# 若信息面板已显示，向左偏移以补偿面板占用的右侧空间，
	# 确保地点出现在可视区域的中心而非被面板遮挡。
	if _info_panel.visible:
		target.x -= PANEL_SHIFT
	target = _guard_pan_bounds(target)
	_animate_pan(target)
	_animate_zoom(old_zoom, KEYBOARD_ZOOM)


## 确保平移目标不超出地图边界 — "尽量居中，遇边界则贴边"。
func _guard_pan_bounds(target: Vector2) -> Vector2:
	var clip_size: Vector2 = _map_clip.size
	var map_w: float = MAP_W * _zoom_level
	var map_h: float = MAP_H * _zoom_level
	var clamped: Vector2 = target
	clamped.x = clampf(clamped.x, clip_size.x - map_w, 0.0)
	clamped.y = clampf(clamped.y, clip_size.y - map_h, 0.0)
	return clamped


func _scroll_to_location(idx: int) -> void:
	var data: Dictionary = LOCATIONS[idx]
	var loc_center: Vector2 = Vector2(data.x, data.y)
	var screen_pos: Vector2 = loc_center * _zoom_level + _map_container.position

	var clip_size: Vector2 = _map_clip.size
	if clip_size.x <= 0 or clip_size.y <= 0:
		return

	var margin: float = SCROLL_MARGIN
	var target: Vector2 = _map_container.position
	var needs_scroll: bool = false

	# 信息面板显示时右侧可视区域收窄，增大右边界触发距离
	var right_limit: float = clip_size.x - (margin + PANEL_SHIFT if _info_panel.visible else margin)
	if screen_pos.x < margin:
		target.x = _map_container.position.x + margin - screen_pos.x
		needs_scroll = true
	elif screen_pos.x > right_limit:
		target.x = _map_container.position.x + right_limit - screen_pos.x
		needs_scroll = true

	if screen_pos.y < margin:
		target.y = _map_container.position.y + margin - screen_pos.y
		needs_scroll = true
	elif screen_pos.y > clip_size.y - margin:
		target.y = _map_container.position.y + (clip_size.y - margin) - screen_pos.y
		needs_scroll = true

	if needs_scroll:
		# 确保滚动目标也不会超出边界
		var map_w: float = MAP_W * _zoom_level
		var map_h: float = MAP_H * _zoom_level
		target.x = clampf(target.x, clip_size.x - map_w, 0.0)
		target.y = clampf(target.y, clip_size.y - map_h, 0.0)
		_animate_pan(target)


func _animate_pan(target: Vector2) -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	# 终止面板动画关联的地图位移 tween，防止与当前平移冲突
	if _map_shift_tween and _map_shift_tween.is_valid():
		_map_shift_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pan_tween.tween_property(_map_container, "position", target, 0.35)

@warning_ignore("unused_parameter")
func _animate_zoom(from_zoom: float, to_zoom: float) -> void:
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_map_container, "scale", Vector2(to_zoom, to_zoom), 0.35)


# ===================================================================
# 平移 / 缩放
# ===================================================================

func _on_map_clip_input(event: InputEvent) -> void:
	if _disabled: return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = false
				_drag_start = mb.position
				_pan_start = _map_container.position
			else:
				if not _dragging and _selected_idx >= 0:
					_deselect_location()
				_dragging = false

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if mm.button_mask & 1:
			var delta: Vector2 = mm.position - _drag_start
			if not _dragging and delta.length() > DRAG_THRESHOLD:
				_dragging = true
			if _dragging:
				_map_container.position = _pan_start + delta
			_clamp_pan()


# ===================================================================
# 标记点击
# ===================================================================

func _on_marker_input(event: InputEvent, idx: int) -> void:
	if _disabled: return
	# Forward drag motion to map panning
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & 1:
		_on_map_clip_input(event)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_play_click()
			if _selected_idx == idx:
				_deselect_location()
			else:
				_select_location(idx, true)
				_center_on_location(idx)


# ===================================================================
# 键盘 / 滚轮 输入
# ===================================================================

func _input(event: InputEvent) -> void:
	if _disabled or not _menu_active:
		return

	# ── 滚轮缩放（_input 中处理确保不被拦截）──
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(ZOOM_STEP, mb.position)
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(1.0 / ZOOM_STEP, mb.position)
			return
		return

	if event is InputEventMouseMotion:
		return

	if not event.is_pressed():
		return

	# Enter / Space → 弹出当前选中地点的详情框（无选中时恢复上次选中）
	if event.is_action_pressed("ui_accept"):
		if _selected_idx >= 0:
			_update_info_panel(_selected_idx)
			_center_on_location(_selected_idx)
		elif _last_selected_idx >= 0:
			_select_location(_last_selected_idx, true)
			_center_on_location(_last_selected_idx)
		_play_click()
		get_viewport().set_input_as_handled()
		return

	# ESC — 三步：先关信息面板，再取消选中，最后返回
	# _esc_blocked 防止连按 ESC 时动画被反复杀死/重启导致面板"颤抖"
	if event.is_action_pressed("ui_cancel"):
		if _esc_blocked:
			get_viewport().set_input_as_handled()
			return
		_esc_blocked = true

		if _selected_idx >= 0:
			if _info_panel.visible:
				_hide_info_panel()
			else:
				_deselect_location()
		elif _can_go_back:
			back_requested.emit()

		# 动画最长约 0.35s（zoom）+ 0.3s（panel）= 最多 0.35s 并行，
		# 取 0.45s 安全余量后解锁
		get_tree().create_timer(0.45).timeout.connect(_unblock_esc)
		get_viewport().set_input_as_handled()
		return

	# WASD / 方向键
	var dx: int = 0
	var dy: int = 0
	if event.is_action_pressed("ui_up"):    dy = -1
	elif event.is_action_pressed("ui_down"):  dy = 1
	elif event.is_action_pressed("ui_left"):  dx = -1
	elif event.is_action_pressed("ui_right"): dx = 1

	if dx != 0 or dy != 0:
		if _selected_idx < 0:
			var start_idx: int = _last_selected_idx if _last_selected_idx >= 0 else 0
			_select_location(start_idx)
			_center_on_location(start_idx)
		else:
			var new_idx: int = _find_nearest_in_direction(dx, dy)
			var show_info: bool = _info_panel.visible
			if new_idx >= 0:
				_play_click()
				_select_location(new_idx, show_info)
				_center_on_location(new_idx)
			else:
				# 死路 — 无地点可跳转，重新选中当前位置使其居中
				_play_click()
				_select_location(_selected_idx, show_info)
				_center_on_location(_selected_idx)
		get_viewport().set_input_as_handled()


func _find_nearest_in_direction(dx: int, dy: int) -> int:
	var cur: Dictionary = LOCATIONS[_selected_idx]
	var cx: float = cur.x
	var cy: float = cur.y
	var best_idx: int = -1
	var best_dist: float = INF

	for i: int in range(LOCATIONS.size()):
		if i == _selected_idx:
			continue
		var loc: Dictionary = LOCATIONS[i]
		var lx: float = loc.x
		var ly: float = loc.y
		var x_diff: float = lx - cx
		var y_diff: float = ly - cy

		# 方向过滤
		if dx < 0 and x_diff >= 0: continue
		if dx > 0 and x_diff <= 0: continue
		if dy < 0 and y_diff >= 0: continue
		if dy > 0 and y_diff <= 0: continue

		# 加权距离 — 主轴全权重，垂直轴 ×3 惩罚
		var dist: float = 0.0
		if dx != 0:
			dist = absf(x_diff) + absf(y_diff) * 3.0
		else:
			dist = absf(y_diff) + absf(x_diff) * 3.0

		if best_idx < 0 or dist < best_dist:
			best_dist = dist
			best_idx = i

	return best_idx


func _apply_zoom(factor: float, anchor_screen: Vector2) -> void:
	var old_zoom: float = _zoom_level
	var new_zoom: float = clampf(_zoom_level * factor, _zoom_min, ZOOM_MAX)
	if is_equal_approx(new_zoom, old_zoom):
		return

	var map_anchor: Vector2 = (anchor_screen - _map_container.position) / old_zoom
	_zoom_level = new_zoom
	_map_container.position = anchor_screen - map_anchor * _zoom_level
	_clamp_pan()
	_map_container.scale = Vector2(_zoom_level, _zoom_level)


# ===================================================================
# SceneManager 生命周期
# ===================================================================

func _on_enter() -> void:
	_disabled = false
	_esc_blocked = false

	# 等待一帧使布局生效，然后计算初始缩放：地图至少填满裁剪区 → 无黑边
	await get_tree().process_frame
	var clip_size: Vector2 = _map_clip.size
	if clip_size.x > 0 and clip_size.y > 0:
		var fit_x: float = clip_size.x / MAP_W
		var fit_y: float = clip_size.y / MAP_H
		_zoom_min = maxf(fit_x, fit_y)
		_zoom_level = _zoom_min
		_map_container.scale = Vector2(_zoom_level, _zoom_level)
		# 居中
		_map_container.position = (clip_size - Vector2(MAP_W, MAP_H) * _zoom_level) / 2.0

	_menu_active = true

	# 首次选中 = 当前地点（存档作用域 current_location）；
	# 未设置 / 不在地图上 → 默认北门（LOCATIONS 第一项）。选择浏览不回写。
	var loc_idx: int = MapData.get_index(GameManager.get_current_location())
	_select_location(loc_idx if loc_idx >= 0 else 0, false)

func _on_exit() -> void:
	_disabled = true
	_menu_active = false
	# 音频模糊保持不变 —— 返回路径上 Tab 菜单已重新打开（_open_tab_menu
	# 先于本回调执行），此处若关闭菜单模式会覆盖 Tab 菜单刚开启的低通滤波。
	# 最终关闭由 VNInterface._on_tab_menu_closed / _back_to_menu 负责。


# ===================================================================
# 辅助
# ===================================================================

func _on_back_pressed() -> void:
	if _disabled: return
	back_requested.emit()


func _unblock_esc() -> void:
	_esc_blocked = false


func _play_click() -> void:
	AudioManager.play_click()


## 控制场景是否可通过 ESC / BackBar 返回上一级。
## 当 @return scene:MAP 经 FlowManager 直接从剧本跳转且无法返回时，设为 false。
func set_can_go_back(can: bool) -> void:
	_can_go_back = can
	if _back_bar:
		_back_bar.visible = can


func set_disabled(val: bool) -> void:
	_disabled = val
