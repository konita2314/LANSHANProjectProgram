## MainMenuList : VBoxContainer
## 主菜单条目列表组件 — 挂到 MainMenu.tscn 的 %MenuList（VBox 分离 0 自动堆叠）。
## 职责：行构建/文本刷新/焦点状态/键盘导航/入场错峰动画/退出模态调暗。
## 行样式与焦点动画照 TabMenu 选项实现（纯 Label + sweep 扫白 + 行 position.x
## tween + 颜色瞬时覆盖）：全量行焦点刷新、逐行独立 tween 先杀后建，
## 避免半程 kill 残留中间态（"鼠标移开后动画暂停"的根因）。
## 入场动画照 git 版：行从右侧 x=100 错峰滑入静止位，快速淡入先于滑动完成。
## 零 autoload 依赖：数据经 rebuild/refresh_entries 参数传入，事件经信号发出；
## 音效与视差由 MainMenu 编排层在 selection_changed/item_activated 信号中处理。
class_name MainMenuList
extends VBoxContainer

# ── Signals ────────────────────────────────────────────

## 选中项变化（仅用户发起且去重后发出；index 为选中索引）。
signal selection_changed(index)
## 条目被激活（鼠标点击或 ui_accept）。
signal item_activated(index)
## 请求取消（ESC / ui_cancel）。
signal cancel_requested()

# ── Constants（样式/动画数值照 TabMenu）──────────────────

const ROW_HEIGHT: float = 51.0
const ROW_FOCUS_X: float = -50.0   # 聚焦行左移（TabMenu）
const ROW_REST_X: float = 10.0     # 未聚焦行右移（TabMenu）
const UNFOCUSED_MODULATE: float = 0.35
const TITLE_FONT_SIZE: int = 42
const ZH_FONT_SIZE: int = 24
const UNFOCUSED_ZH_COLOR: Color = Color(1, 1, 1, 0.5)
const FOCUSED_ZH_COLOR: Color = Color(0, 0, 0, 0.6)
const SWEEP_COLOR: Color = Color.WHITE
const FOCUS_DURATION: float = 0.25
const INTRO_START_X: float = 100.0   # 入场起始位：右侧屏外（git 版）
const INTRO_STAGGER: float = 0.08
const INTRO_FADE_DURATION: float = 0.3
const INTRO_SLIDE_DURATION: float = 0.5
const LEAD_SPACER_WIDTH: float = 16.0
const MID_SPACER_WIDTH: float = 12.0

# ── State ──────────────────────────────────────────────

var _selection: MenuSelection = null
var _rows: Array[Row] = []
var _interactive: bool = false
var _row_focus_tweens: Array[Tween] = []
var _dim_tween: Tween = null
var _intro_tweens: Array[Tween] = []
var _title_font: Font = null
var _subtitle_font: Font = null

## 行类型化引用（取代 set_meta/get_meta）。
class Row:
	var root: Control = null
	var sweep: ColorRect = null
	var title_label: Label = null
	var subtitle_label: Label = null


# ── Public API ─────────────────────────────────────────

func set_fonts(p_title_font: Font, p_subtitle_font: Font) -> void:
	_title_font = p_title_font
	_subtitle_font = p_subtitle_font


## 初建：清空旧行，按 entries（已按 locale 解析好 subtitle）重建全部行。
func rebuild(entries: Array[Dictionary]) -> void:
	_kill_focus_tweens()
	for row: Row in _rows:
		row.root.queue_free()
	_rows.clear()
	_selection = MenuSelection.new(entries.size(), true)
	for i: int in range(entries.size()):
		var entry: Dictionary = entries[i]
		var title_text: String = entry["title"]
		var subtitle_text: String = entry["subtitle"]
		_rows.append(_build_row(i, title_text, subtitle_text))


## 仅更新文本不重建节点（重进场景复用行，性能）。数量不一致时退化为 rebuild。
func refresh_entries(entries: Array[Dictionary]) -> void:
	if entries.size() != _rows.size():
		rebuild(entries)
		return
	for i: int in range(_rows.size()):
		var entry: Dictionary = entries[i]
		_rows[i].title_label.text = entry["title"]
		_rows[i].subtitle_label.text = entry["subtitle"]


## 瞬时复位视觉状态 — 消除被 kill 的 tween 残留中间值（审阅点 4）。
func reset_visual_state() -> void:
	for row: Row in _rows:
		row.root.position.x = 0.0
		row.sweep.scale.x = 0.0
		row.root.modulate.a = 1.0


## 交互门控；关闭时杀全部焦点 tween 防止残留动画覆盖退出模态的调暗。
func set_interactive(p_interactive: bool) -> void:
	_interactive = p_interactive
	if not p_interactive:
		_kill_focus_tweens()


## 全量行焦点刷新（TabMenu 同法）：先杀上一轮全部行 tween，再为每行独立
## tween（sweep/position/modulate），文字颜色瞬时覆盖（theme override）。
## 必须全量而非"上一项+新项"：半程 kill 会让未在目标集内的行停在中间态
## （快速移开鼠标后动画看似"暂停"），全量刷新保证所有行收敛到终值。
func apply_focus() -> void:
	if _rows.is_empty():
		return
	_kill_focus_tweens()
	for i: int in range(_rows.size()):
		var row: Row = _rows[i]
		var is_focused: bool = i == _selection.get_selected()
		var target_x: float = ROW_FOCUS_X if is_focused else ROW_REST_X
		var target_alpha: float = 1.0 if is_focused else UNFOCUSED_MODULATE
		var target_sweep_scale: float = 1.0 if is_focused else 0.0
		var target_title_color: Color = Color.BLACK if is_focused else Color.WHITE
		var target_zh_color: Color = FOCUSED_ZH_COLOR if is_focused else UNFOCUSED_ZH_COLOR
		# 颜色瞬时切换，不参与 tween — 避免 kill 残留中间色
		row.title_label.add_theme_color_override("font_color", target_title_color)
		row.subtitle_label.add_theme_color_override("font_color", target_zh_color)
		var row_tween: Tween = create_tween().set_parallel(true)
		row_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		row_tween.tween_property(row.sweep, "scale:x", target_sweep_scale, FOCUS_DURATION)
		row_tween.tween_property(row.root, "position:x", target_x, FOCUS_DURATION)
		row_tween.tween_property(row.root, "modulate:a", target_alpha, FOCUS_DURATION)
		_row_focus_tweens.append(row_tween)
	_selection.mark_focus_applied()


## 清除焦点历史（兼容接口：全量刷新后历史不再影响行为，保留调用方语义）。
func reset_focus_history() -> void:
	_selection.reset_focus_history()


## 退出模态调暗/恢复共用单一写入点（amount=1.0 恢复）。
func set_dim(amount: float, duration: float) -> void:
	if _dim_tween and _dim_tween.is_valid():
		_dim_tween.kill()
	_dim_tween = create_tween().set_parallel(true)
	for row: Row in _rows:
		_dim_tween.tween_property(row.root, "modulate:a", amount, duration)


## 入场前初始态：行全透明并右移屏外（git 版进入动画：淡入 + 100→静止位滑动）。
func prepare_intro() -> void:
	for row: Row in _rows:
		row.root.modulate.a = 0.0
		row.root.position.x = INTRO_START_X


## 入场错峰动画（git 版同法）：每行并行「快速淡入 0.3 + 从右侧 INTRO_START_X
## 滑到静止位 ROW_REST_X 0.5」，错峰 i*0.08，EXPO/EASE_OUT。淡入先于滑动完成，
## 避免"滑到一半才出现"的错觉（git 注释原话）。不翻转 _interactive —
## 由 MainMenu 编排。等待最后一行完成。
func play_intro_stagger() -> void:
	_intro_tweens.clear()
	var last_tween: Tween = null
	for i: int in range(_rows.size()):
		var row: Row = _rows[i]
		var delay: float = i * INTRO_STAGGER
		var row_tween: Tween = create_tween().set_parallel(true)
		row_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		row_tween.tween_property(row.root, "modulate:a", 1.0, INTRO_FADE_DURATION).set_delay(delay)
		row_tween.tween_property(row.root, "position:x", ROW_REST_X, INTRO_SLIDE_DURATION).set_delay(delay)
		_intro_tweens.append(row_tween)
		last_tween = row_tween
	if last_tween:
		await last_tween.finished
	_intro_tweens.clear()


## 场景退出时批量终止全部动画（焦点/调暗/入场错峰）。
func kill_animations() -> void:
	_kill_focus_tweens()
	if _dim_tween and _dim_tween.is_valid():
		_dim_tween.kill()
	for intro_tween: Tween in _intro_tweens:
		if intro_tween.is_valid():
			intro_tween.kill()
	_intro_tweens.clear()


## 杀全部行焦点 tween（先杀后建，防新旧争抢 — TabMenu _row_focus_tweens 同法）。
func _kill_focus_tweens() -> void:
	for tw: Tween in _row_focus_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_row_focus_tweens.clear()


# ── Row factory（样式照 TabMenu _make_row：sweep + 内容 HBox）──

func _build_row(index: int, title_text: String, subtitle_text: String) -> Row:
	var row: Row = Row.new()
	row.root = Control.new()
	row.root.name = "Item_" + str(index)
	row.root.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(row.root)

	# 白色扫入（聚焦时 scale.x 0→1，pivot 左缘；锚全行适配窗口收拢）
	row.sweep = ColorRect.new()
	row.sweep.name = "Sweep"
	row.sweep.color = SWEEP_COLOR
	row.sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.sweep.pivot_offset = Vector2(0, 0)
	row.sweep.scale.x = 0.0
	row.sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.root.add_child(row.sweep)

	# 内容行：前导间隔 + EN 标题 + 间隔 + 中文副标题（END 对齐靠右）
	var content_row: HBoxContainer = HBoxContainer.new()
	content_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_row.alignment = BoxContainer.ALIGNMENT_END
	content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.root.add_child(content_row)

	var lead_spacer: Control = Control.new()
	lead_spacer.custom_minimum_size = Vector2(LEAD_SPACER_WIDTH, 0)
	lead_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(lead_spacer)

	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _title_font:
		title_label.add_theme_font_override("font", _title_font)
	content_row.add_child(title_label)
	row.title_label = title_label

	var mid_spacer: Control = Control.new()
	mid_spacer.custom_minimum_size = Vector2(MID_SPACER_WIDTH, 0)
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(mid_spacer)

	# 中文副标题（英文模式为空文本 ~0 宽；样式照 TabMenu 单 Label 24px）
	var subtitle_label: Label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = subtitle_text
	subtitle_label.add_theme_font_size_override("font_size", ZH_FONT_SIZE)
	subtitle_label.add_theme_color_override("font_color", UNFOCUSED_ZH_COLOR)
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _subtitle_font:
		subtitle_label.add_theme_font_override("font", _subtitle_font)
	content_row.add_child(subtitle_label)
	row.subtitle_label = subtitle_label

	# 悬停→选中→焦点链（审阅点 2）：变化去重后由 _on_row_hover 统一走 apply_focus + 信号
	row.root.mouse_entered.connect(_on_row_hover.bind(index))
	row.root.gui_input.connect(_on_row_click.bind(index))
	return row


# ── Input handlers ─────────────────────────────────────

func _on_row_hover(index: int) -> void:
	if not _interactive:
		return
	if not _selection.select(index):
		return
	apply_focus()
	selection_changed.emit(_selection.get_selected())


func _on_row_click(ev: InputEvent, index: int) -> void:
	if not _interactive:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		item_activated.emit(index)


func _input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_move(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_move(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		item_activated.emit(_selection.get_selected())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_requested.emit()
		get_viewport().set_input_as_handled()


## 键盘移动：MenuSelection.move 变化才刷新焦点并发信号（边界按键不重复触发）。
func _move(direction: int) -> void:
	if not _selection.move(direction):
		return
	apply_focus()
	selection_changed.emit(_selection.get_selected())
