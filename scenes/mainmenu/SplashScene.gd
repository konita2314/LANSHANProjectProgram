## SplashScene : Control
## 启动画面，先显示 logo，然后显示警告/法律声明。
## 从 App.tsx 移植的 SplashScene。
extends Control

enum Step { LOGO, WARNING, EXIT }

var _step: Step = Step.LOGO
var _logo_timer: float = 0.0
var _warning_timer: float = 0.0
var _logo_duration: float = 3.0
var _warning_duration: float = 5.5
var _can_skip: bool = true
var _switching: bool = false

@onready var _logo_container: Control = %LogoContainer
@onready var _warning_container: Control = %WarningContainer
@onready var _logo_image: TextureRect = %LogoImage
@onready var _notice_label: Label = %NoticeLabel
@onready var _epilepsy_label: Label = %EpilepsyLabel
@onready var _legal_label: Label = %LegalLabel
@onready var _continue_label: Label = %ContinueLabel


func _ready() -> void:
	# TCM font for English titles (matches web "Century Gothic")
	var tcm: Font = load(GameManager.FONT_TCM)
	var zh_body: Font = load(GameManager.FONT_ZH_BODY)
	var en_body: Font = load(GameManager.FONT_EN_BODY)
	if tcm:
		_notice_label.add_theme_font_override("font", tcm)

	# Body font — content-aware (text may contain CJK in any locale)
	@warning_ignore("static_called_on_instance")
	_epilepsy_label.add_theme_font_override("font", GameManager.select_font(_epilepsy_label.text, zh_body, en_body))
	@warning_ignore("static_called_on_instance")
	_legal_label.add_theme_font_override("font", GameManager.select_font(_legal_label.text, zh_body, en_body))
	@warning_ignore("static_called_on_instance")
	_continue_label.add_theme_font_override("font", GameManager.select_font(_continue_label.text, zh_body, en_body))

	_setup_logo_display()
	_setup_warning_display()
	_show_logo()


func _setup_logo_display() -> void:
	var logo_texture := _load_texture("res://assets/icons/fws_logo.png")
	if logo_texture:
		_logo_image.texture = logo_texture
	_logo_container.visible = true
	_logo_container.modulate.a = 0.0


func _setup_warning_display() -> void:
	_warning_container.visible = false
	_warning_container.modulate.a = 0.0

	_notice_label.text = "Notice"
	_notice_label.add_theme_font_size_override("font_size", 72)

	_epilepsy_label.text = tr("极少数人在接触某些特定光影模式或闪烁光线时，可能会出现癫痫发作或暂时性失神。在电视屏幕上观看特定画面、背景，或在进行电子游戏时，这些模式可能会诱发癫痫症状。如您出现不适，请咨询医生。")

	_legal_label.text = tr("游戏内容纯属虚构，出现的人名、地名等均为虚构，如有雷同纯属巧合。游戏中提到的观点仅作剧情使用，不代表作者观点。")

	_continue_label.text = tr("按任意处继续 - 继续则表示您已同意以上条款。")


func _show_logo() -> void:
	_step = Step.LOGO
	_logo_container.visible = true
	_logo_container.modulate.a = 0.0
	_warning_container.visible = false
	_logo_timer = 0.0
	_switching = false

	var tween := create_tween()
	tween.tween_property(_logo_container, "modulate:a", 1.0, 1.5).set_ease(Tween.EASE_IN_OUT)


func _show_warning() -> void:
	if _switching: return
	_switching = true
	_step = Step.WARNING
	_warning_timer = 0.0

	# Fade out logo first
	var fade_out := create_tween()
	fade_out.tween_property(_logo_container, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	await fade_out.finished
	_logo_container.visible = false

	# Fade in warning
	_warning_container.visible = true
	_warning_container.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	fade_in.tween_property(_warning_container, "modulate:a", 1.0, 1.0)
	await fade_in.finished

	# Animate divider line
	var divider := _warning_container.get_node_or_null("%DividerLine") as ColorRect
	if divider:
		divider.size.x = 0.0
		var dt := create_tween()
		dt.tween_property(divider, "size:x", 60.0, 0.8).set_ease(Tween.EASE_OUT)

	_switching = false


func _go_to_menu() -> void:
	if _switching: return
	_switching = true
	_step = Step.EXIT

	# Emit immediately — SceneManager's fade-through-black transition
	# handles the visual exit smoothly. No self-fade avoids a double-fade
	# that creates an awkward black gap before the main menu appears.
	EventBus.scene_changed.emit("TITLE")


func _process(delta: float) -> void:
	if _switching: return
	if _step == Step.LOGO:
		_logo_timer += delta
		if _logo_timer >= _logo_duration:
			_show_warning()
	elif _step == Step.WARNING:
		_warning_timer += delta
		if _warning_timer >= _warning_duration:
			_go_to_menu()


func _input(event: InputEvent) -> void:
	if not _can_skip:
		return
	if event.is_pressed() and (event is InputEventKey or event is InputEventMouseButton):
		if _step == Step.LOGO:
			_show_warning()
		elif _step == Step.WARNING:
			_go_to_menu()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("SplashScene: Texture not found — ", path)
	return null
