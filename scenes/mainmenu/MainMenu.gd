## MainMenu : Control — 主菜单编排者。
## 职责收敛：常量块、入场动画编排、退出模态生命周期、视差、背景兜底。
## 条目列表已下沉 MainMenuList（行构建/焦点/导航/调暗），退出模态在 QuitModal。
## 符合 CLAUDE.md 规范：无 lambda，严格类型，@onready 已类型化。
extends Control

# ── Constants ──────────────────────────────────────────

## 菜单条目唯一数据源（路由在此）。subtitle 为中文原文，经 tr() 翻译。
const MENU_ITEMS: Array[Dictionary] = [
	{ "title": "New Game", "subtitle": "开始游戏", "target": "REGISTRATION" },
	{ "title": "Load",     "subtitle": "继续游戏", "target": "LOAD" },
	{ "title": "Rewards",  "subtitle": "历程",     "target": "REWARDS" },
	{ "title": "Config",   "subtitle": "设置",     "target": "SETTINGS" },
	{ "title": "About",    "subtitle": "关于",     "target": "ABOUT" },
	{ "title": "Exit",     "subtitle": "退出游戏", "target": "" },
]

## 静态场景依赖 fail-fast：工程文件缺失应在解析期暴露，保证"用户永远能退出"。
const QUIT_MODAL_SCENE: PackedScene = preload("res://scenes/mainmenu/QuitModal.tscn")

# 布局（与 tscn 锚点默认值一致；_clamp_layout 在极小窗口下按 EDGE_MARGIN 收拢）
const BRAND_OFFSET_X: float = 600.0
const BRAND_OFFSET_Y: float = 60.0
const MENU_OFFSET_LEFT: float = 680.0
const MENU_OFFSET_RIGHT: float = 60.0
const EDGE_MARGIN: float = 16.0

# 入场动画
const ENTRY_PAUSE: float = 0.2
const BRAND_SLIDE_OFFSET: float = 50.0
const BRAND_POSITION_Y: float = 60.0   # 须与 tscn Branding offset_top 一致
const BRAND_INTRO_DURATION: float = 1.0
const BRAND_LINE_WIDTH: float = 500.0  # 须与 tscn BrandLine offset_right 一致
const BRAND_LINE_DURATION: float = 0.9
const BRAND_LINE_DELAY: float = 0.3

# 退出模态
const QUIT_ITEM_DIM: float = 0.15
const QUIT_BRAND_DIM: float = 0.3
const QUIT_DIM_DURATION: float = 0.4
const QUIT_RESTORE_DURATION: float = 0.3
const QUIT_CLEANUP_DELAY: float = 0.3

# 视差
const PARALLAX_STEP_PX: float = 15.0
const PARALLAX_MARGIN_RATIO: float = 0.075  # BackgroundLayer 1.15 缩放，(1.15-1)/2

# 品牌副标题（"火兰山中学"书法字）
const BRAND_SUBTITLE_FIRST_SIZE: int = 36
const BRAND_SUBTITLE_SIZE_CYCLE: Array[int] = [28, 24, 22, 24]
const BRAND_SUBTITLE_COLOR: Color = Color(1, 1, 1, 0.8)

# ── State ──────────────────────────────────────────────

var _intro_running: bool = false
var _intro_tweens: Array[Tween] = []
var _entry_complete: bool = false
var _overlay_tween: Tween = null
var _quit_modal: QuitModal = null
var _cleaning_up: bool = false  # 防止快速按 ESC 导致重复清理

# ── Onready ────────────────────────────────────────────

@onready var _brand: Control = %Branding
@onready var _brand_title: Label = %BrandTitle
@onready var _brand_footer: Label = %BrandFooter
@onready var _brand_sub: Control = %BrandSub
@onready var _brand_line: ColorRect = %BrandLine
@onready var _brand_icon: TextureRect = %BrandIcon
@onready var _menu_list: MainMenuList = %MenuList


# ── Lifecycle ──────────────────────────────────────────

func _ready() -> void:
	_setup_branding()
	_clamp_layout()
	get_tree().root.size_changed.connect(_clamp_layout)

	_menu_list.set_fonts(GameManager.font_tcm, GameManager.font_zh_title)
	_menu_list.selection_changed.connect(_on_selection_changed)
	_menu_list.item_activated.connect(_on_item_activated)
	_menu_list.cancel_requested.connect(_on_cancel_requested)
	_menu_list.rebuild(_build_entries())

	# 首帧渲染前进入初始态（参照 git 版：条目在 await 前即预隐藏）。
	# 若延迟到 _play_entry 内才隐藏，首帧会全量闪现再消失，入场动画观感"错误"。
	# VBox 的排序在空闲时执行，会覆写此处的 position.x —— _play_entry 在
	# await 一帧后会再次 prepare_intro，以排序后的位置为基准重设初始位。
	_prepare_brand_intro()
	_menu_list.prepare_intro()

	# 短暂延迟让场景在动画开始前变得可见。
	await get_tree().process_frame
	await _play_entry()


## 防御性守卫：canvas_items + keep 下逻辑视口恒 1280×720，仅非默认拉伸配置触发。
## 视口不足时按 EDGE_MARGIN 收拢品牌/菜单锚点偏移；否则恢复 tscn 默认锚点值。
func _clamp_layout() -> void:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	if viewport_width < MENU_OFFSET_LEFT + MENU_OFFSET_RIGHT:
		_menu_list.offset_left = -viewport_width + EDGE_MARGIN
		_menu_list.offset_right = -EDGE_MARGIN
	else:
		_menu_list.offset_left = -MENU_OFFSET_LEFT
		_menu_list.offset_right = -MENU_OFFSET_RIGHT
	if viewport_width < BRAND_OFFSET_X + EDGE_MARGIN:
		_brand.offset_left = -viewport_width + EDGE_MARGIN
		_brand.offset_right = -viewport_width + EDGE_MARGIN
	else:
		_brand.offset_left = -BRAND_OFFSET_X
		_brand.offset_right = -BRAND_OFFSET_X


func _setup_branding() -> void:
	_brand_title.add_theme_font_override("font", GameManager.font_tcm)
	if GameManager.font_en_body:
		_brand_footer.add_theme_font_override("font", GameManager.font_en_body)

	var icon: Texture2D = load("res://assets/icons/icon.png")
	if icon:
		_brand_icon.texture = icon

	# 品牌副标题"火兰山中学"：tr 无英文键，Type F 例外恒显（见 translate.md）
	for child in _brand_sub.get_children():
		child.queue_free()
	var brand_subtitle := SubtitleLabel.new()
	brand_subtitle.set_calligraphic_text(tr("火兰山中学"), BRAND_SUBTITLE_FIRST_SIZE, BRAND_SUBTITLE_SIZE_CYCLE, BRAND_SUBTITLE_COLOR, GameManager.font_zh_title)
	_brand_sub.add_child(brand_subtitle)


## 按 locale 解析菜单条目数据（语言规则见下：未来语言需在此扩展字典）。
func _build_entries() -> Array[Dictionary]:
	# 语言规则（过渡方案）：非 zh locale 即隐藏中文副标题。
	# 未来新增语言需改为按 locale 取键的字典（如 {"zh": "开始游戏", "ja": "..."}），MENU_ITEMS 需扩展。
	var show_zh: bool = GameManager.is_locale("zh")
	var entries: Array[Dictionary] = []
	for item: Dictionary in MENU_ITEMS:
		var title: String = item["title"]
		var subtitle: String = "" if not show_zh else tr(item["subtitle"])
		entries.append({ "title": title, "subtitle": subtitle })
	return entries


## 兜底背景：正常轮换由 GameManager 60s 定时器 → BackgroundLayer 完成，本函数仅处理
## 空/失效路径；仅在路径变化时写回并广播（避免重进菜单时背景闪黑）。
func _ensure_menu_background() -> void:
	var path: String = GameManager.current_background
	if path.is_empty() or not ResourceLoader.exists(path):
		path = GameManager.BG_POOL[randi() % GameManager.BG_POOL.size()]
		if not ResourceLoader.exists(path):
			return
		GameManager.current_background = path
		EventBus.shared_background_updated.emit(path)


# ── Entry animation ────────────────────────────────────

## 两阶段顺序入场：
##   阶段 1 — 品牌信息滑入 + 线条展开（线条 tween 与菜单项阶段并行，无死隙）
##   阶段 2 — 菜单项错峰淡入滑动（由 MainMenuList 执行）
##   完成后开放交互并应用初始焦点。
func _play_entry() -> void:
	if _intro_running:
		return
	_intro_running = true
	_prepare_brand_intro()
	_menu_list.prepare_intro()

	# 动画开始前短暂静止 — 避免"瞬间运动"的感觉
	await get_tree().create_timer(ENTRY_PAUSE).timeout

	var brand_tween: Tween = _play_brand_intro()
	_intro_tweens.append(brand_tween)
	if brand_tween:
		await brand_tween.finished

	await _menu_list.play_intro_stagger()

	_entry_complete = true
	_menu_list.set_interactive(true)
	# 焦点延迟一帧 — 冲刷滑入动画期间的悬停信号，避免
	# "聚焦项 0 → 鼠标悬停项 3 → 取消并重新聚焦"的闪烁。
	await get_tree().process_frame
	_menu_list.apply_focus()
	_intro_running = false


func _prepare_brand_intro() -> void:
	_brand.modulate.a = 0.0
	_brand.position.y = BRAND_POSITION_Y - BRAND_SLIDE_OFFSET
	_brand_line.size.x = 0.0


## 品牌并行 tween：y 回位 + 淡入（1.0s QUINT）；线条展开（0.9s，延迟 0.3）。
## 返回品牌 tween 供 _play_entry await；线条 tween 登记入 _intro_tweens。
func _play_brand_intro() -> Tween:
	var brand_tween: Tween = create_tween().set_parallel(true)
	brand_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	brand_tween.tween_property(_brand, "position:y", BRAND_POSITION_Y, BRAND_INTRO_DURATION)
	brand_tween.tween_property(_brand, "modulate:a", 1.0, BRAND_INTRO_DURATION)

	var line_tween: Tween = create_tween()
	line_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	line_tween.tween_property(_brand_line, "size:x", BRAND_LINE_WIDTH, BRAND_LINE_DURATION).set_delay(BRAND_LINE_DELAY)
	_intro_tweens.append(line_tween)
	return brand_tween


# ── Signal routing ─────────────────────────────────────

func _on_selection_changed(index: int) -> void:
	_parallax(index)
	_play_click()


func _on_item_activated(index: int) -> void:
	_play_click()
	var target: String = MENU_ITEMS[index].target
	if target.is_empty():
		_show_quit()
	else:
		EventBus.scene_changed.emit(target)


func _on_cancel_requested() -> void:
	_show_quit()


## 视差偏移：选中项偏离中心越远偏移越大（BackgroundLayer 消费 bg_parallax_offset）。
func _parallax(index: int) -> void:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var center_index: float = float(MENU_ITEMS.size() - 1) * 0.5
	var center_offset: float = viewport_width * PARALLAX_MARGIN_RATIO
	var offset_x: float = (index - center_index) * -PARALLAX_STEP_PX - center_offset
	EventBus.bg_parallax_offset.emit(offset_x)


func _play_click() -> void:
	AudioManager.play_click()


# ── Quit modal lifecycle ───────────────────────────────

func _show_quit() -> void:
	if _quit_modal or _cleaning_up or _intro_running:
		return

	var modal: QuitModal = QUIT_MODAL_SCENE.instantiate() as QuitModal
	_quit_modal = modal
	modal.confirmed.connect(_on_quit_confirmed)
	modal.cancelled.connect(_on_quit_cancelled)
	add_child(modal)

	_menu_list.set_interactive(false)
	AudioManager.set_menu_mode(true)

	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()
	_overlay_tween = create_tween().set_parallel(true)
	_overlay_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_menu_list.set_dim(QUIT_ITEM_DIM, QUIT_DIM_DURATION)
	_overlay_tween.tween_property(_brand, "modulate:a", QUIT_BRAND_DIM, QUIT_DIM_DURATION)


func _on_quit_confirmed() -> void:
	await _cleanup_quit()
	get_tree().quit()


func _on_quit_cancelled() -> void:
	await _cleanup_quit()
	if _quit_modal:
		return
	_menu_list.set_interactive(true)
	_menu_list.reset_focus_history()
	_menu_list.apply_focus()  # 全量修复被调暗覆盖的焦点态


func _cleanup_quit() -> void:
	var modal: QuitModal = _quit_modal
	if not modal or _cleaning_up:
		return
	_cleaning_up = true

	AudioManager.set_menu_mode(false)
	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()
	_overlay_tween = create_tween().set_parallel(true)
	_overlay_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_menu_list.set_dim(1.0, QUIT_RESTORE_DURATION)
	_overlay_tween.tween_property(_brand, "modulate:a", 1.0, QUIT_RESTORE_DURATION)

	await get_tree().create_timer(QUIT_CLEANUP_DELAY).timeout
	if is_instance_valid(modal):
		modal.queue_free()
	if _quit_modal == modal:
		_quit_modal = null
	_cleaning_up = false


# ── SceneManager lifecycle ─────────────────────────────

func _on_exit() -> void:
	_intro_running = false
	_cleaning_up = false
	_menu_list.set_interactive(false)
	_menu_list.kill_animations()
	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()
	for intro_tween: Tween in _intro_tweens:
		if intro_tween.is_valid():
			intro_tween.kill()
	_intro_tweens.clear()
	if _quit_modal:
		_quit_modal.queue_free()
		_quit_modal = null


func _on_enter() -> void:
	_ensure_menu_background()
	# 仅在重新进入时激活菜单（从另一个场景返回）。
	# 首次加载时，_play_entry() 控制完整的动画序列，
	# 并在完成时启用菜单。
	if not _entry_complete:
		return
	_menu_list.refresh_entries(_build_entries())
	_menu_list.reset_visual_state()
	await get_tree().process_frame
	_menu_list.set_interactive(true)
	_menu_list.reset_focus_history()
	_menu_list.apply_focus()
