## Tips : Control
## 教程弹窗 — 由 SceneManager 挂载在 CanvasLayer（layer 99，位于 AchievementReached 下方），
## 用于在游戏中显示多页教程提示。弹窗居中，缩放淡入。
## 标题固定为 "Tips"。弹窗期间拦截一切操作，只能推进/回退 tip。
## A / W / ← / ↑ → 上一页；其余任意键 → 下一页（末页时关闭）。
## 页面间内容平滑过渡，无闪烁。F7 调试触发预设页面。
extends Control

signal dismissed()

const TIP_SHOW_DUR: float = 0.4           # 面板入场时长
const TIP_HIDE_DUR: float = 0.35          # 面板退场时长
const TIP_BG_FADE_DUR: float = 0.6        # 背景淡入淡出时长（柔和过渡）
const TIP_STAGGER_DUR: float = 0.5        # 内部元素错峰动画时长
const TIP_BOX_DELAY: float = 0.06         # TitleBox 白条展开延迟
const TIP_DESC_DELAY: float = 0.08        # DescLabel 延迟
const TIP_PAGE_DELAY: float = 0.10        # PageLabel 延迟
const TIP_ENTER_SCALE: float = 0.85       # 入场起始缩放
const TIP_CROSSFADE_DUR: float = 0.15     # 翻页时内容交叉淡入淡出时长

const DEBUG_PAGES: Array[Dictionary] = [
	{"desc": "欢迎来到兰山计划。\n这是一个教程示例。"},
	{"desc": "ESC 键可以打开菜单。\n在视觉小说中，点击或按空格键继续对话。"},
	{"desc": "在地图界面，使用鼠标拖拽移动视角。\n点击地点图标可以查看详情。"},
]

var _tip_pages: Array[Dictionary] = []
var _tip_current_page: int = -1
var _tip_active: bool = false
var _tip_first_show: bool = true
var _tip_slide_tween: Tween = null
var _tip_stagger_tweens: Array[Tween] = []
var _debug_armed: bool = false       # 首次场景切换后才允许 F7，避免主菜单冲突

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: Control = $TipPanel
@onready var _title_box: ColorRect = $TipPanel/TitleBox
@onready var _title_label: Label = $TipPanel/TitleLabel
@onready var _desc_label: Label = $TipPanel/DescLabel
@onready var _page_label: Label = $TipPanel/PageLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.visible = false
	_panel.visible = false
	EventBus.show_tips.connect(_on_show_tips)
	EventBus.scene_changed.connect(_on_tips_scene_changed)


# ===================================================================
# 输入 — 弹窗期间拦截一切操作
# ===================================================================

func _input(event: InputEvent) -> void:
	# F7 调试（仅 Debug 构建，首次场景切换后才允许，避免主菜单冲突）
	if OS.is_debug_build() and event is InputEventKey:
		var dk: InputEventKey = event as InputEventKey
		if dk.pressed and not dk.echo and dk.keycode == KEY_F7:
			if not _tip_active and _debug_armed:
				_on_show_tips(DEBUG_PAGES)
			return

	if not _tip_active:
		return

	# 弹窗期间拦截一切输入 — 只处理翻页，其余全部吃掉
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed or key.echo:
			get_viewport().set_input_as_handled()
			return

		match key.keycode:
			# A / W / ← / ↑ → 上一页
			KEY_A, KEY_W, KEY_LEFT, KEY_UP:
				_tip_go_prev()
			# 其余任意键 → 下一页
			_:
				_tip_go_next()

		get_viewport().set_input_as_handled()
		return

	# 拦截鼠标事件
	get_viewport().set_input_as_handled()


# ===================================================================
# 公共接口
# ===================================================================

func _on_tips_scene_changed(_name: String) -> void:
	_debug_armed = true
func _on_show_tips(pages: Array[Dictionary]) -> void:
	if pages.is_empty():
		return
	_tip_pages = pages.duplicate(true)
	_tip_current_page = 0
	_tip_first_show = true
	_tip_show_current_page()


# ===================================================================
# 翻页
# ===================================================================

func _tip_go_prev() -> void:
	if _tip_current_page > 0:
		_tip_current_page -= 1
		_tip_first_show = false
		_tip_show_current_page()


func _tip_go_next() -> void:
	if _tip_current_page < _tip_pages.size() - 1:
		_tip_current_page += 1
		_tip_first_show = false
		_tip_show_current_page()
	else:
		_tip_dismiss()


func _tip_show_current_page() -> void:
	if _tip_pages.is_empty() or _tip_current_page < 0 or _tip_current_page >= _tip_pages.size():
		return

	_tip_active = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var page: Dictionary = _tip_pages[_tip_current_page]

	_title_label.text = "Tips"
	_desc_label.text = page.get("desc", "")
	_page_label.text = "%d / %d" % [_tip_current_page + 1, _tip_pages.size()]

	if GameManager.font_tcm:
		_title_label.add_theme_font_override("font", GameManager.font_tcm)
	@warning_ignore("static_called_on_instance")
	var desc_font: Font = GameManager.select_font(_desc_label.text, GameManager.font_zh_body, GameManager.font_en_body)
	if desc_font: _desc_label.add_theme_font_override("font", desc_font)

	_tip_kill_anim_tweens()

	if _tip_first_show:
		# ── 首次入场：完整动画 ──
		_backdrop.visible = true
		_backdrop.modulate.a = 0.0
		var t_bg: Tween = create_tween()
		t_bg.tween_property(_backdrop, "modulate:a", 1.0, TIP_BG_FADE_DUR)

		_panel.visible = true
		_panel.modulate.a = 0.0
		_panel.pivot_offset = _panel.size / 2.0
		_panel.scale = Vector2(TIP_ENTER_SCALE, TIP_ENTER_SCALE)
		_tip_slide_tween = create_tween().set_parallel(true)
		_tip_slide_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		_tip_slide_tween.tween_property(_panel, "modulate:a", 1.0, TIP_SHOW_DUR)
		_tip_slide_tween.tween_property(_panel, "scale", Vector2.ONE, TIP_SHOW_DUR)

		# TitleBox 白条展开
		_title_box.scale = Vector2(0.0, 1.0)
		var t_box: Tween = create_tween()
		t_box.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_box.tween_property(_title_box, "scale:x", 1.0, TIP_STAGGER_DUR).set_delay(TIP_BOX_DELAY)
		_tip_stagger_tweens.append(t_box)

		# TitleLabel 淡入
		_title_label.modulate.a = 0.0
		var t_title: Tween = create_tween()
		t_title.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_title.tween_property(_title_label, "modulate:a", 1.0, TIP_STAGGER_DUR * 0.7).set_delay(TIP_BOX_DELAY + 0.04)
		_tip_stagger_tweens.append(t_title)

		# DescLabel 淡入
		_desc_label.modulate.a = 0.0
		var t_desc: Tween = create_tween()
		t_desc.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_desc.tween_property(_desc_label, "modulate:a", 1.0, TIP_STAGGER_DUR * 0.7).set_delay(TIP_DESC_DELAY)
		_tip_stagger_tweens.append(t_desc)

		# PageLabel 淡入
		_page_label.modulate.a = 0.0
		var t_page: Tween = create_tween()
		t_page.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_page.tween_property(_page_label, "modulate:a", 1.0, TIP_STAGGER_DUR * 0.5).set_delay(TIP_PAGE_DELAY)
		_tip_stagger_tweens.append(t_page)
	else:
		# ── 翻页：内容交叉淡入淡出，面板和背景不动 ──
		_desc_label.modulate.a = 0.0
		var t_desc: Tween = create_tween()
		t_desc.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_desc.tween_property(_desc_label, "modulate:a", 1.0, TIP_CROSSFADE_DUR)
		_tip_stagger_tweens.append(t_desc)

		_page_label.modulate.a = 0.0
		var t_page: Tween = create_tween()
		t_page.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t_page.tween_property(_page_label, "modulate:a", 1.0, TIP_CROSSFADE_DUR).set_delay(0.04)
		_tip_stagger_tweens.append(t_page)


# ===================================================================
# 关闭
# ===================================================================

func _tip_dismiss() -> void:
	_tip_kill_anim_tweens()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 面板和背景一起淡出
	_tip_slide_tween = create_tween().set_parallel(true)
	_tip_slide_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	_tip_slide_tween.tween_property(_panel, "modulate:a", 0.0, TIP_BG_FADE_DUR)
	_tip_slide_tween.tween_property(_backdrop, "modulate:a", 0.0, TIP_BG_FADE_DUR)
	# chain 确保淡出完成后才回调（parallel 里的 callback 是即时的！）
	_tip_slide_tween.chain().tween_callback(_tip_on_dismissed)


func _tip_on_dismissed() -> void:
	_panel.visible = false
	_backdrop.visible = false
	_panel.modulate.a = 1.0
	_panel.scale = Vector2.ONE
	_title_box.scale = Vector2.ONE
	_title_label.modulate.a = 1.0
	_desc_label.modulate.a = 1.0
	_page_label.modulate.a = 1.0
	_tip_active = false
	_tip_pages.clear()
	_tip_current_page = -1
	dismissed.emit()


# ===================================================================
# 动画辅助
# ===================================================================

func _tip_kill_anim_tweens() -> void:
	if _tip_slide_tween and _tip_slide_tween.is_valid():
		_tip_slide_tween.kill()
	for t: Tween in _tip_stagger_tweens:
		if t and t.is_valid():
			t.kill()
	_tip_stagger_tweens.clear()
