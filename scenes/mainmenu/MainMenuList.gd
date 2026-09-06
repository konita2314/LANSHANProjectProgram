## MainMenuList : VBoxContainer
## 主菜单条目列表组件 — 挂到 MainMenu.tscn 的 %MenuList（VBox 分离 0 自动堆叠）。
## 职责：行构建/文本刷新/焦点状态/键盘导航/入场错峰动画/退出模态调暗。
## 行本体为 scenes/ui/OptionRow 统一组件（sweep 扫白 + 位移 + 调暗 + 颜色瞬时覆盖，
## 焦点先杀后建无半程残留）；本类仅编排列表级状态（MenuSelection）与入场节奏。
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

# ── Constants ──────────────────────────────────────────

const INTRO_STAGGER: float = 0.08   # 入场错峰（行样式数值见 OptionRow）

# ── State ──────────────────────────────────────────────

var _selection: MenuSelection = null
var _rows: Array[OptionRow] = []
var _interactive: bool = false
var _intro_tweens: Array[Tween] = []
var _title_font: Font = null
var _subtitle_font: Font = null


# ── Public API ─────────────────────────────────────────

func set_fonts(p_title_font: Font, p_subtitle_font: Font) -> void:
	_title_font = p_title_font
	_subtitle_font = p_subtitle_font


## 初建：清空旧行，按 entries（已按 locale 解析好 subtitle）重建全部行。
func rebuild(entries: Array[Dictionary]) -> void:
	for row: OptionRow in _rows:
		row.kill_anims()
		row.queue_free()
	_rows.clear()
	_selection = MenuSelection.new(entries.size(), true)
	for i: int in range(entries.size()):
		var entry: Dictionary = entries[i]
		var row := OptionRow.new()
		row.setup(i, entry["title"], entry["subtitle"], _title_font, _subtitle_font)
		row.hovered.connect(_on_row_hovered)
		row.activated.connect(_on_row_activated)
		add_child(row)
		_rows.append(row)


## 仅更新文本不重建节点（重进场景复用行，性能）。数量不一致时退化为 rebuild。
func refresh_entries(entries: Array[Dictionary]) -> void:
	if entries.size() != _rows.size():
		rebuild(entries)
		return
	for i: int in range(_rows.size()):
		var entry: Dictionary = entries[i]
		_rows[i].refresh_text(entry["title"], entry["subtitle"])


## 瞬时复位视觉状态 — 消除被 kill 的 tween 残留中间值。
func reset_visual_state() -> void:
	for row: OptionRow in _rows:
		row.reset_visual_state()


## 交互门控；关闭时杀全部行焦点动画防止残留动画覆盖退出模态的调暗。
func set_interactive(p_interactive: bool) -> void:
	_interactive = p_interactive
	if not p_interactive:
		_kill_focus_anims()


## 全量行焦点刷新（TabMenu 同法）：每行自身先杀后建（见 OptionRow.apply_focus_state），
## 全量而非"上一项+新项"保证所有行收敛到终值（快速移开鼠标后动画不"暂停"）。
func apply_focus() -> void:
	if _rows.is_empty():
		return
	for i: int in range(_rows.size()):
		_rows[i].apply_focus_state(i == _selection.get_selected())
	_selection.mark_focus_applied()


## 清除焦点历史（兼容接口：全量刷新后历史不再影响行为，保留调用方语义）。
func reset_focus_history() -> void:
	_selection.reset_focus_history()


## 退出模态调暗/恢复共用单一写入点（amount=1.0 恢复）。
func set_dim(amount: float, duration: float) -> void:
	for row: OptionRow in _rows:
		row.set_dim(amount, duration)


## 入场前初始态：行全透明并右移屏外（git 版进入动画：淡入 + 100→静止位滑动）。
func prepare_intro() -> void:
	for row: OptionRow in _rows:
		row.prepare_intro()


## 入场错峰动画：每行「快速淡入 + 右侧屏外滑到静止位」，错峰 i*0.08。
## 淡入先于滑动完成，避免"滑到一半才出现"的错觉（git 注释原话）。
## 不翻转 _interactive — 由 MainMenu 编排。等待最后一行完成。
func play_intro_stagger() -> void:
	_intro_tweens.clear()
	var last_tween: Tween = null
	for i: int in range(_rows.size()):
		var row_tween: Tween = _rows[i].play_intro(i * INTRO_STAGGER)
		_intro_tweens.append(row_tween)
		last_tween = row_tween
	if last_tween:
		await last_tween.finished
	_intro_tweens.clear()


## 场景退出时批量终止全部动画（焦点/调暗/入场错峰）。
func kill_animations() -> void:
	for row: OptionRow in _rows:
		row.kill_anims()
	for intro_tween: Tween in _intro_tweens:
		if intro_tween.is_valid():
			intro_tween.kill()
	_intro_tweens.clear()


## 杀全部行焦点动画（先杀后建，防新旧争抢 — TabMenu _row_focus_tweens 同法）。
func _kill_focus_anims() -> void:
	for row: OptionRow in _rows:
		row.kill_focus_anim()


# ── Input handlers ─────────────────────────────────────

func _on_row_hovered(index: int) -> void:
	if not _interactive:
		return
	if not _selection.select(index):
		return
	apply_focus()
	selection_changed.emit(_selection.get_selected())


func _on_row_activated(index: int) -> void:
	if not _interactive:
		return
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
