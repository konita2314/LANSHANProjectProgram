## RegistrationScene : Control
## 模拟浏览器的"志愿填报"表单，用于玩家姓名输入。
extends Control

signal registration_complete(player_name: String)
signal registration_cancelled()

const MAX_DISPLAY_CHARS: int = 8       # 游戏中显示的字符数
const MAX_INPUT_CHARS: int = 256       # 文本字段允许的字符数

# 预加载的已注册角色名称列表 — 拒绝这些名称
const BLOCKED_NAMES: Array[String] = preload("res://scripts/resources/RegisteredNames.gd").NAMES

var _player_name: String = ""
var _show_warning: bool = false
var _interactive: bool = false

@onready var _backdrop: ColorRect = %Backdrop
@onready var _chrome_bar: ColorRect = %ChromeBar
@onready var _tab_label: Label = %TabLabel
@onready var _close_button: Button = %CloseButton
@onready var _page_title: Label = %PageTitle
@onready var _page_subtitle: Label = %PageSubtitle
@onready var _name_input: LineEdit = %NameInput
@onready var _confirm_button: Button = %ConfirmButton
@onready var _warning_banner: Label = %WarningBanner
@onready var _toast: Control = %Toast
@onready var _toast_label: Label = %ToastLabel

# === 静态表单文本（用于统一翻译和应用字体） ===
@onready var _lbl_photo: Label = %LblPhoto
@onready var _lbl_name: Label = %LblName
@onready var _lbl_gender: Label = %LblGender
@onready var _val_gender: Label = %ValGender
@onready var _lbl_dob: Label = %LblDob
@onready var _lbl_region: Label = %LblRegion
@onready var _val_region: Label = %ValRegion
@onready var _lbl_school: Label = %LblSchool
@onready var _val_school: Label = %ValSchool
@onready var _lbl_id: Label = %LblId

func _ready() -> void:
	_setup_interaction()
	
	_name_input.max_length = MAX_INPUT_CHARS
	_name_input.caret_blink = true
	_name_input.caret_blink_interval = 0.5
	_name_input.text_changed.connect(_on_name_changed)
	
	_close_button.pressed.connect(_on_cancel)
	_confirm_button.pressed.connect(_on_confirm)
	
	_warning_banner.modulate.a = 0.0
	_toast.visible = false
	_toast.modulate.a = 0.0

## 每次场景激活时由 SceneManager 调用。
## 重置所有状态，防止上一次会话的数据泄露。
func _on_enter() -> void:
	_player_name = ""
	_name_input.text = ""
	_name_input.editable = true
	_name_input.grab_focus()
	_refresh_translations()
	_hide_banner()
	_interactive = false
	_animate_enter()

func _refresh_translations() -> void:
	# 翻译文本更新
	_tab_label.text = tr("中考志愿填报")
	_page_title.text = tr("帛日市教育局 中考志愿填报系统")
	_page_subtitle.text = tr("请确认身份信息。")
	_confirm_button.text = tr("确定")
	_toast_label.text = tr("请先在该网页中完成姓名填报内容。")
	_name_input.placeholder_text = tr("请输入姓名")
	
	_lbl_photo.text = tr("暂无照片")
	_lbl_name.text = tr("姓名")
	_lbl_gender.text = tr("性别")
	_val_gender.text = tr("男")
	_lbl_dob.text = tr("出生日期")
	_lbl_region.text = tr("户籍所在地")
	_val_region.text = tr("帛日市浮城区")
	_lbl_school.text = tr("第一志愿")
	_val_school.text = tr("帛日火兰山中学")
	_lbl_id.text = tr("考生号")

	# 使用数据驱动模式统一更新字体，避免代码冗长
	var font_targets = [
		[_tab_label, GameManager.font_zh_title, GameManager.font_tcm],
		[_page_title, GameManager.font_zh_title, GameManager.font_tcm],
		[_page_subtitle, GameManager.font_zh_body, GameManager.font_en_body],
		[_confirm_button, GameManager.font_zh_title, GameManager.font_tcm],
		[_toast_label, GameManager.font_zh_body, GameManager.font_en_body],
		[_lbl_photo, GameManager.font_zh_title, GameManager.font_tcm],
		[_lbl_name, GameManager.font_zh_body, GameManager.font_en_body],
		[_lbl_gender, GameManager.font_zh_body, GameManager.font_en_body],
		[_val_gender, GameManager.font_zh_body, GameManager.font_en_body],
		[_lbl_dob, GameManager.font_zh_body, GameManager.font_en_body],
		[_lbl_region, GameManager.font_zh_body, GameManager.font_en_body],
		[_val_region, GameManager.font_zh_body, GameManager.font_en_body],
		[_lbl_school, GameManager.font_zh_body, GameManager.font_en_body],
		[_val_school, GameManager.font_zh_body, GameManager.font_en_body],
		[_lbl_id, GameManager.font_zh_body, GameManager.font_en_body]
	]
	
	for target in font_targets:
		var node = target[0]
		@warning_ignore("static_called_on_instance")
		node.add_theme_font_override("font", GameManager.select_font(node.text, target[1], target[2]))

func _on_exit() -> void:
	_interactive = false

# ── 交互控制 ───────────────────────────────────────────────────────

func _setup_interaction() -> void:
	_backdrop.gui_input.connect(_on_outside_clicked)
	_chrome_bar.gui_input.connect(_on_outside_clicked)

func _on_outside_clicked(event: InputEvent) -> void:
	if not _interactive: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _player_name.strip_edges().is_empty():
			_show_banner(tr("警告：还未输入姓名"))

func _show_banner(msg: String) -> void:
	_show_warning = true
	_warning_banner.text = msg
	_warning_banner.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_warning_banner, "modulate:a", 1.0, 0.3)

func _hide_banner() -> void:
	_show_warning = false
	var tween := create_tween()
	tween.tween_property(_warning_banner, "modulate:a", 0.0, 0.25)

# ── 核心逻辑与验证 ────────────────────────────────────────────────────

func _on_name_changed(new_text: String) -> void:
	_player_name = new_text
	if _show_warning and not _player_name.strip_edges().is_empty():
		_hide_banner()

func _on_confirm() -> void:
	@warning_ignore("shadowed_variable_base_class")
	var name: String = _player_name.strip_edges()
	if name.is_empty():
		_show_banner(tr("警告：还未输入姓名"))
		_play_click()
		return

	if name.length() > MAX_DISPLAY_CHARS:
		_show_banner(tr("名称长度不匹配"))
		_play_click()
		return

	# 拒绝空格和符号 — 允许字母、数字、CJK、假名、注音符号
	var has_symbol: bool = false
	for ch: String in name:
		var c: int = ch.unicode_at(0)
		var ok: bool = false
		if (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A): ok = true
		elif (c >= 0x30 and c <= 0x39): ok = true
		elif (c >= 0x4E00 and c <= 0x9FFF): ok = true
		elif (c >= 0x3400 and c <= 0x4DBF): ok = true
		elif (c >= 0x3040 and c <= 0x309F): ok = true
		elif (c >= 0x30A0 and c <= 0x30FF): ok = true
		elif (c >= 0x3100 and c <= 0x312F): ok = true
		elif (c >= 0xFF01 and c <= 0xFF5E): ok = true
		if not ok:
			has_symbol = true
			break
			
	if has_symbol:
		_show_banner(tr("名称含无效字符"))
		_play_click()
		return

	for blocked: String in BLOCKED_NAMES:
		if name == blocked:
			_show_banner(tr("未找到该用户"))
			_name_input.text = ""
			_name_input.grab_focus()
			_play_click()
			return

	_play_click()
	registration_complete.emit(name)

func _on_cancel() -> void:
	_play_click()
	registration_cancelled.emit()

# ── 动画 ────────────────────────────────────────────────────────

func _animate_enter() -> void:
	modulate.a = 0.0
	var window = get_node("BrowserWindow")
	if window: 
		window.scale = Vector2(0.96, 0.96)
		# 强制设置枢轴点到中心
		window.pivot_offset = window.size / 2
		
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	if window: tween.tween_property(window, "scale", Vector2(1, 1), 0.5)
	tween.chain().tween_callback(_enable_interaction)

func _enable_interaction() -> void:
	_interactive = true

# ── 音频 ────────────────────────────────────────────────────────

func _play_click() -> void:
	AudioManager.play_click()

# ── 输入系统 ─────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event.is_pressed():
		return

	if event.is_action_pressed("ui_cancel"):
		# ESC 劫持：拦截按键但不退出，仅顶部关闭按钮可退出
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		if not _name_input.has_focus():
			_on_confirm()
			get_viewport().set_input_as_handled()