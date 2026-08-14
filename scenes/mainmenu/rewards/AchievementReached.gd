## AchievementReached : Control
## 成就达成全局弹窗 — 由 SceneManager 挂载在顶层 CanvasLayer，
## 出现在一切场景之上，不拦截其他场景的输入。
## 监听 EventBus.achievement_unlocked：右上角滑入提示，
## 停留 2 秒后自动滑出；鼠标悬停时暂停倒计时（移开后继续）。
## 进出场动画参照 Map InfoPanel / 主菜单 QuitModal：
## 面板整体从屏幕右缘滑入（TRANS_QUINT），内部元素错峰滑入淡入，
## 退出时加速滑出屏幕（TRANS_EXPO EASE_IN）。
## 样式与 ESC 返回栏一致：NameLabel 白底黑字；悬停仅暂停倒计时，不改变样式。
extends Control

const SHOW_DUR: float = 0.45           # 面板滑入时长 — 对齐 QuitModal Band 0.45s
const HIDE_DUR: float = 0.3            # 面板滑出时长 — 对齐 InfoPanel 隐藏 0.3s
const HOLD_TIME: float = 1.0
const EDGE_MARGIN: float = 32.0        # 滑出屏幕右缘所需的额外余量
const STAGGER_OFFSET: float = 50.0     # 内部元素错峰滑入距离 — 对齐 InfoPanel 的 50px
const STAGGER_DUR: float = 0.5         # 内部元素错峰动画时长
const BOX_DELAY: float = 0.08          # NameBox 白条展开延迟
const NAME_DELAY: float = 0.16         # NameLabel 错峰延迟
const DESC_DELAY: float = 0.26         # DescLabel 错峰延迟

const AchievementsData: GDScript = preload("res://scripts/resources/AchievementsData.gd")

var _queue: Array[String] = []
var _showing: bool = false
var _hovered: bool = false
var _slide_tween: Tween = null
var _stagger_tweens: Array[Tween] = []
var _hold_timer: Timer = null
var _tip_rest_x: float = 0.0
var _name_rest_x: float = 0.0
var _desc_rest_x: float = 0.0


@onready var _tip: Control = $ReachTip
@onready var _name_box: ColorRect = $ReachTip/NameBox
@onready var _name_label: Label = $ReachTip/NameLabel
@onready var _desc_label: Label = $ReachTip/DescLabel


func _ready() -> void:

	# 根节点不拦截任何输入 — 不影响其他场景
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip_rest_x = _tip.position.x
	_name_rest_x = _name_label.position.x
	_desc_rest_x = _desc_label.position.x

	# 停留倒计时 — 悬停时暂停
	_hold_timer = Timer.new()
	_hold_timer.name = "HoldTimer"
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_TIME
	_hold_timer.timeout.connect(_dismiss)
	add_child(_hold_timer)

	_tip.mouse_entered.connect(_on_tip_hover.bind(true))
	_tip.mouse_exited.connect(_on_tip_hover.bind(false))
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)


# ===================================================================
# 队列 — 连续达成多个成就时依次展示
# ===================================================================

func _on_achievement_unlocked(achievement_id: String) -> void:
	_queue.append(achievement_id)
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		return
	_showing = true
	var achievement_id: String = _queue.pop_front()

	_name_label.text = tr("已达成成就：")
	_desc_label.text = tr(achievement_id)
	@warning_ignore("static_called_on_instance")
	var name_font: Font = GameManager.select_font(_name_label.text, GameManager.font_zh_title, GameManager.font_tcm)
	if name_font: _name_label.add_theme_font_override("font", name_font)
	@warning_ignore("static_called_on_instance")
	var desc_font: Font = GameManager.select_font(_desc_label.text, GameManager.font_zh_body, GameManager.font_en_body)
	if desc_font: _desc_label.add_theme_font_override("font", desc_font)

	_kill_anim_tweens()

	# ── 面板整体从屏幕右缘滑入 — 参照 InfoPanel：只动位置，不做整体淡入 ──
	_tip.visible = true
	_tip.modulate.a = 1.0
	_tip.position.x = _tip_rest_x + _slide_dist()
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(_tip, "position:x", _tip_rest_x, SHOW_DUR)
	_slide_tween.tween_callback(_start_hold)

	# ── 内部元素逐级入场 — 对齐 QuitModal / InfoPanel 的错峰节奏 ──

	# NameBox — 白条从左向右展开（对齐 QuitModal Band / InfoPanel 分割线）
	_name_box.scale = Vector2(0.0, 1.0)
	var t_box: Tween = create_tween()
	t_box.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_box.tween_property(_name_box, "scale:x", 1.0, STAGGER_DUR).set_delay(BOX_DELAY)
	_stagger_tweens.append(t_box)

	# NameLabel — 右侧滑入 + 淡入
	_name_label.position.x = _name_rest_x + STAGGER_OFFSET
	_name_label.modulate.a = 0.0
	var t_name: Tween = create_tween().set_parallel(true)
	t_name.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_name.tween_property(_name_label, "position:x", _name_rest_x, STAGGER_DUR).set_delay(NAME_DELAY)
	t_name.tween_property(_name_label, "modulate:a", 1.0, STAGGER_DUR).set_delay(NAME_DELAY)
	_stagger_tweens.append(t_name)

	# DescLabel — 右侧滑入 + 淡入
	_desc_label.position.x = _desc_rest_x + STAGGER_OFFSET
	_desc_label.modulate.a = 0.0
	var t_desc: Tween = create_tween().set_parallel(true)
	t_desc.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_desc.tween_property(_desc_label, "position:x", _desc_rest_x, STAGGER_DUR).set_delay(DESC_DELAY)
	t_desc.tween_property(_desc_label, "modulate:a", 1.0, STAGGER_DUR).set_delay(DESC_DELAY)
	_stagger_tweens.append(t_desc)


func _start_hold() -> void:
	_hold_timer.start()
	# 滑入期间鼠标已悬停 → 立即暂停倒计时
	_hold_timer.paused = _hovered


func _dismiss() -> void:
	_kill_anim_tweens()
	# 面板向屏幕右缘加速滑出 — 参照 InfoPanel 隐藏（TRANS_EXPO EASE_IN）
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_slide_tween.tween_property(_tip, "position:x", _tip_rest_x + _slide_dist(), HIDE_DUR)
	_slide_tween.tween_callback(_on_dismissed)


func _on_dismissed() -> void:
	_tip.visible = false
	# 复位所有动画状态 — 下一条提示从干净状态入场
	_tip.position.x = _tip_rest_x
	_name_box.scale = Vector2.ONE
	_name_label.position.x = _name_rest_x
	_name_label.modulate.a = 1.0
	_desc_label.position.x = _desc_rest_x
	_desc_label.modulate.a = 1.0
	_showing = false
	_show_next()


# ===================================================================
# 动画辅助
# ===================================================================

## 完全滑出屏幕右缘所需的位移（面板宽度 + 右侧留白 + 余量）。
func _slide_dist() -> float:
	return _tip.size.x + EDGE_MARGIN


func _kill_anim_tweens() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	for t: Tween in _stagger_tweens:
		if t and t.is_valid():
			t.kill()
	_stagger_tweens.clear()


# ===================================================================
# 悬停 — 仅暂停倒计时，NameBox / NameLabel 样式保持不变
# ===================================================================

func _on_tip_hover(hovered: bool) -> void:
	_hovered = hovered
	if _showing and not _hold_timer.is_stopped():
		_hold_timer.paused = hovered
