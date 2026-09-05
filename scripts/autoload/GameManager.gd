## GameManager : Node (Autoload)
## 全局单例，用于游戏状态、存档/读档和设置持久化。
extends Node

const SAVES_PATH: String = "user://saves.cfg"
const SETTINGS_PATH: String = "user://settings.cfg"
const FIRST_LAUNCH_PATH: String = "user://first_launch.cfg"
const ACHIEVEMENTS_PATH: String = "user://achievements.cfg"
const PERSIST_VARS_PATH: String = "user://persist_vars.cfg"
const FIRST_LAUNCH_KEY: String = "launched"
const AUTOSAVE_KEY: String = "autosave"
const MAX_SLOTS: int = 20
const BG_ROTATE_INTERVAL: float = 60.0

# 成就静态定义 — 成就系统不依赖存档，全局持久化
const AchievementsData: GDScript = preload("res://scripts/resources/AchievementsData.gd")

# 所有可轮换的背景图像组合池
const BG_POOL: Array[String] = [
	"res://assets/backgrounds/menu/1.webp",
	"res://assets/backgrounds/menu/2.webp",
	"res://assets/backgrounds/menu/3.webp",
	"res://assets/backgrounds/menu/4.webp",
	"res://assets/backgrounds/menu/5.webp",
	"res://assets/backgrounds/menu/6.webp",
	"res://assets/backgrounds/menu/7.webp",
	"res://assets/backgrounds/menu/8.webp",
	"res://assets/backgrounds/menu/9.webp",
]


# 集中字体路径 — 加载一次，全局使用
const FONT_TCM: String = "res://assets/fonts/TCM_____.TTF"
const FONT_ZH_TITLE: String = "res://assets/fonts/SourceHanSerifCN-SemiBold-7.otf"
const FONT_ZH_BODY: String = "res://assets/fonts/SourceHanSerifCN-Medium-6.otf"
const FONT_ZH_EMPHASIS: String = "res://assets/fonts/simfang.ttf"
const FONT_EN_BODY: String = "res://assets/fonts/times.ttf"
const FONT_EN_EMPHASIS: String = "res://assets/fonts/timesi.ttf"

# 集中加载的 Font 实例 — _ready() 中加载一次（autoload 先于所有场景就绪），
# 各场景直接引用 GameManager.font_*，不再各自声明 _font_* 字段与 load 行。
var font_tcm: Font = null
var font_zh_title: Font = null
var font_zh_body: Font = null
var font_en_body: Font = null
var font_zh_emphasis: Font = null
var font_en_emphasis: Font = null

var player_name: String = ""
var current_plot_id: String = ""
var current_node_index: int = 0
var current_title: String = ""
var current_background: String = ""    # 子场景共享背景 — 与主菜单同步

## VN 运行时变量上下文 — 由 VNInterface.setup() 赋值
## 任何 .gd / .tscn 均可通过 GameManager.script_context 访问
var script_context: ScriptContext = null


## 当前地点（存档作用域 current_location；未设置返回 ""，消费侧回退默认北门）
func get_current_location() -> String:
	if script_context:
		var v: Variant = script_context.get_var("current_location")
		if typeof(v) == TYPE_STRING and not v.is_empty():
			return v
	return ""


## 地点系统唯一写入入口 — @locate 运行时与 Map"前往"都经此调用。
## 写时存储原值（读时回退），仅开发模式对无效名给出警告。
func set_current_location(location_name: String) -> void:
	if not script_context:
		push_warning("GameManager: set_current_location called without script_context — ", location_name)
		return
	if OS.is_debug_build() and not MapData.has_location(location_name):
		push_warning("GameManager: location not on map — ", location_name, "（地图将回退默认）")
	script_context.set_var("current_location", location_name)
	EventBus.location_changed.emit(location_name)

var _settings: AppSettings
var _saves: Array  # Array[SaveData | null] size MAX_SLOTS
var _save_config: ConfigFile
var _bg_timer: Timer = null
var _bg_last_index: int = -1

# 成就状态 — 与存档无关的全局变量（见 AchievementList.gd 规范注释）
var _unlocked_achievements: Dictionary = {}   # id: String → true
var _achievement_counters: Dictionary = {}    # id: String → int（计数型成就累计次数）

# 持久化变量 — 跨所有存档的账号级标记（成就触发等），由 ScriptContext 回调写入
var _persist_vars: Dictionary = {}


func _ready() -> void:
	font_tcm = load(FONT_TCM)
	font_zh_title = load(FONT_ZH_TITLE)
	font_zh_body = load(FONT_ZH_BODY)
	font_en_body = load(FONT_EN_BODY)
	font_zh_emphasis = load(FONT_ZH_EMPHASIS)
	font_en_emphasis = load(FONT_EN_EMPHASIS)
	_load_settings()
	_load_saves()
	_load_achievements()
	_load_persist_vars()
	_start_bg_rotation()
	_apply_locale()
	_apply_framerate()


# ===================================================================
# 背景轮换 — 每 60 秒选择一个新背景
# ===================================================================

func _start_bg_rotation() -> void:
	if _bg_timer:
		return
	_bg_timer = Timer.new()
	_bg_timer.name = "BgRotateTimer"
	_bg_timer.wait_time = BG_ROTATE_INTERVAL
	_bg_timer.one_shot = false
	_bg_timer.timeout.connect(_on_bg_rotate)
	add_child(_bg_timer)
	_bg_timer.start()


func _on_bg_rotate() -> void:
	var new_path: String = _pick_different_bg()
	if new_path.is_empty():
		return
	current_background = new_path
	EventBus.shared_background_updated.emit(new_path)


## 选择一个与当前背景不同的随机背景。
func _pick_different_bg() -> String:
	if BG_POOL.is_empty():
		return ""
	if BG_POOL.size() == 1:
		return BG_POOL[0]

	var idx: int = randi() % BG_POOL.size()
	# 避免连续选择相同的图像
	var attempts: int = 0
	while idx == _bg_last_index and attempts < 10:
		idx = randi() % BG_POOL.size()
		attempts += 1
	_bg_last_index = idx
	return BG_POOL[idx]


# --- 设置 ---

func get_settings() -> AppSettings:
	return _settings


func set_setting(key: String, value: Variant) -> void:
	match key:
		"language":
			_settings.language = value
			_apply_locale()
		"text_speed":
			_settings.text_speed = value
		"master_volume":
			_settings.master_volume = value
		"bgm_volume":
			_settings.bgm_volume = value
		"sfx_volume":
			_settings.sfx_volume = value
		"ambience_volume":
			_settings.ambience_volume = value
		"auto_play":
			_settings.auto_play = value
		"quality":
			_settings.quality = value
		"display_mode":
			_settings.display_mode = value
		"framerate":
			_settings.framerate = value
			_apply_framerate()
	_save_settings()
	EventBus.settings_changed.emit(key, value)


func update_settings(new_settings: Dictionary) -> void:
	for key in new_settings:
		set_setting(key, new_settings[key])


func _load_settings() -> void:
	_settings = AppSettings.new().get_default()
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for key in ["language", "text_speed", "master_volume", "bgm_volume", "sfx_volume", "ambience_volume", "auto_play", "quality", "display_mode", "framerate"]:
			if config.has_section_key("settings", key):
				_settings.set(key, config.get_value("settings", key))

	# 首次启动检测：如果用户从未启动过，
	# 从操作系统区域设置自动检测语言并持久化选择。
	var fl_config := ConfigFile.new()
	if fl_config.load(FIRST_LAUNCH_PATH) != OK:
		var os_locale: String = OS.get_locale().to_lower()
		if os_locale.begins_with("zh"):
			_settings.language = "ZH"
		else:
			_settings.language = "EN"
		_save_settings()
		fl_config.set_value(FIRST_LAUNCH_KEY, "timestamp", str(Time.get_unix_time_from_system()))
		fl_config.save(FIRST_LAUNCH_PATH)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "language", _settings.language)
	config.set_value("settings", "text_speed", _settings.text_speed)
	config.set_value("settings", "master_volume", _settings.master_volume)
	config.set_value("settings", "bgm_volume", _settings.bgm_volume)
	config.set_value("settings", "sfx_volume", _settings.sfx_volume)
	config.set_value("settings", "ambience_volume", _settings.ambience_volume)
	config.set_value("settings", "auto_play", _settings.auto_play)
	config.set_value("settings", "quality", _settings.quality)
	config.set_value("settings", "display_mode", _settings.display_mode)
	config.set_value("settings", "framerate", _settings.framerate)
	var err: int = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("GameManager: Failed to save settings — ", SETTINGS_PATH, " (error ", err, ")")


# ── 帧率设置 ─────────────────────────────────────────────

## 帧率档位 → Engine.max_fps 数值（"vsync"/"unlimited" 特殊处理，不进映射）。
const FRAMERATE_LIMITS: Dictionary = {
	"fps30": 30,
	"fps60": 60,
	"fps120": 120,
	"fps240": 240,
}


## 应用帧率设置（启动时与设置变更时调用）。
## "vsync"：开启垂直同步且 max_fps 不设限 — 引擎自动跟随显示器刷新率，
## 当前实际帧率即显示器最高刷新率（"当前最高帧率即目前显示器的最高帧率"）。
## "unlimited"：关闭垂直同步且 max_fps 不设限。
## 其余档位：关闭垂直同步，Engine.max_fps 钳制到对应数值。
func _apply_framerate() -> void:
	match _settings.framerate:
		"vsync":
			Engine.max_fps = 0
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		"unlimited":
			Engine.max_fps = 0
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		_:
			var limit: int = int(FRAMERATE_LIMITS.get(_settings.framerate, 0))
			Engine.max_fps = limit
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


# --- 存档 / 读档 ---

func get_save_slots() -> Array:
	return _saves


func save_game(slot: int, plot_id: String, node_idx: int, pname: String, title: String, desc: String, variables: Dictionary = {}) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	var save := SaveData.new()
	save.id = _generate_id()
	save.timestamp = int(Time.get_unix_time_from_system())
	save.date = Time.get_datetime_string_from_system(false)
	save.title = title
	save.desc = desc.substr(0, min(desc.length(), 50)) + ("..." if desc.length() > 50 else "")
	save.player_name = pname
	save.plot_id = plot_id
	save.node_index = node_idx
	save.variables = variables.duplicate(true)
	_saves[slot] = save
	_persist_saves()
	EventBus.game_saved.emit(slot)


func load_game(slot: int) -> SaveData:
	if slot < 0 or slot >= MAX_SLOTS:
		return null
	return _saves[slot]


func set_auto_save(plot_id: String, node_idx: int, pname: String, title: String, desc: String, variables: Dictionary = {}) -> void:
	var save := SaveData.new()
	save.plot_id = plot_id
	save.node_index = node_idx
	save.player_name = pname
	save.title = title
	save.desc = desc
	save.date = Time.get_datetime_string_from_system(false)
	save.variables = variables.duplicate(true)
	var config := ConfigFile.new()
	config.set_value(AUTOSAVE_KEY, "plot_id", save.plot_id)
	config.set_value(AUTOSAVE_KEY, "node_index", save.node_index)
	config.set_value(AUTOSAVE_KEY, "player_name", save.player_name)
	config.set_value(AUTOSAVE_KEY, "title", save.title)
	config.set_value(AUTOSAVE_KEY, "desc", save.desc)
	config.set_value(AUTOSAVE_KEY, "date", save.date)
	config.set_value(AUTOSAVE_KEY, "variables", save.variables)
	config.save("user://autosave.cfg")


func get_auto_save() -> SaveData:
	var config := ConfigFile.new()
	if config.load("user://autosave.cfg") != OK:
		return null
	var save := SaveData.new()
	save.plot_id = config.get_value(AUTOSAVE_KEY, "plot_id", "")
	save.node_index = config.get_value(AUTOSAVE_KEY, "node_index", 0)
	save.player_name = config.get_value(AUTOSAVE_KEY, "player_name", "")
	save.title = config.get_value(AUTOSAVE_KEY, "title", "")
	save.desc = config.get_value(AUTOSAVE_KEY, "desc", "")
	save.date = config.get_value(AUTOSAVE_KEY, "date", "")
	save.variables = config.get_value(AUTOSAVE_KEY, "variables", {})
	return save


func _load_saves() -> void:
	_saves = []
	_saves.resize(MAX_SLOTS)
	_save_config = ConfigFile.new()
	if _save_config.load(SAVES_PATH) == OK:
		for i in range(MAX_SLOTS):
			var section := "slot_" + str(i)
			if _save_config.has_section(section):
				var save := SaveData.new()
				save.id = _save_config.get_value(section, "id", "")
				save.timestamp = _save_config.get_value(section, "timestamp", 0)
				save.date = _save_config.get_value(section, "date", "")
				save.title = _save_config.get_value(section, "title", "")
				save.desc = _save_config.get_value(section, "desc", "")
				save.player_name = _save_config.get_value(section, "player_name", "")
				save.plot_id = _save_config.get_value(section, "plot_id", "")
				save.node_index = _save_config.get_value(section, "node_index", 0)
				save.variables = _save_config.get_value(section, "variables", {})

				_saves[i] = save


func _persist_saves() -> void:
	var config := ConfigFile.new()
	for i in range(MAX_SLOTS):
		var save: SaveData = _saves[i]
		if save:
			var section := "slot_" + str(i)
			config.set_value(section, "id", save.id)
			config.set_value(section, "timestamp", save.timestamp)
			config.set_value(section, "date", save.date)
			config.set_value(section, "title", save.title)
			config.set_value(section, "desc", save.desc)
			config.set_value(section, "player_name", save.player_name)
			config.set_value(section, "plot_id", save.plot_id)
			config.set_value(section, "node_index", save.node_index)
			config.set_value(section, "variables", save.variables)
	config.save(SAVES_PATH)


# ===================================================================
# 成就 — 全局持久化（不依赖存档槽位）
# ===================================================================

## 返回全部成就静态定义。
func get_achievement_defs() -> Array[Dictionary]:
	return AchievementsData.ENTRIES


## 检查指定成就是否已达成。
func is_achievement_unlocked(achievement_id: String) -> bool:
	return _unlocked_achievements.get(achievement_id, false)


## 返回计数型成就的当前累计次数。
func get_achievement_count(achievement_id: String) -> int:
	return _achievement_counters.get(achievement_id, 0)


## 达成成就。重复调用安全（已达成则忽略）。
func unlock_achievement(achievement_id: String) -> void:
	if is_achievement_unlocked(achievement_id):
		return
	if not _achievement_exists(achievement_id):
		push_warning("GameManager: Unknown achievement — ", achievement_id)
		return
	_unlocked_achievements[achievement_id] = true
	_save_achievements()
	EventBus.achievement_unlocked.emit(achievement_id)


## 累加计数型成就次数，达到目标值时自动解锁。
func add_achievement_count(achievement_id: String, amount: int = 1) -> void:
	if is_achievement_unlocked(achievement_id):
		return
	var target: int = _achievement_target(achievement_id)
	if target <= 0:
		push_warning("GameManager: Achievement is not counter-based — ", achievement_id)
		return
	var count: int = get_achievement_count(achievement_id) + amount
	_achievement_counters[achievement_id] = count
	if count >= target:
		unlock_achievement(achievement_id)
	else:
		_save_achievements()


## 已达成成就占全部成就的百分比（0–100，四舍五入）。
func get_achievement_progress_percent() -> int:
	var total: int = AchievementsData.ENTRIES.size()
	if total == 0:
		return 0
	var unlocked: int = 0
	for entry: Dictionary in AchievementsData.ENTRIES:
		if is_achievement_unlocked(entry.id):
			unlocked += 1
	return int(roundf(unlocked * 100.0 / total))


func _achievement_exists(achievement_id: String) -> bool:
	return not AchievementsData.find_entry(achievement_id).is_empty()


func _achievement_target(achievement_id: String) -> int:
	var entry: Dictionary = AchievementsData.find_entry(achievement_id)
	return entry.get("target", 0)


func _load_achievements() -> void:
	_unlocked_achievements = {}
	_achievement_counters = {}
	var config := ConfigFile.new()
	if config.load(ACHIEVEMENTS_PATH) != OK:
		return
	for entry: Dictionary in AchievementsData.ENTRIES:
		if config.get_value("unlocked", entry.id, false):
			_unlocked_achievements[entry.id] = true
		var count: int = config.get_value("counters", entry.id, 0)
		if count > 0:
			_achievement_counters[entry.id] = count


func _save_achievements() -> void:
	var config := ConfigFile.new()
	for id: String in _unlocked_achievements:
		config.set_value("unlocked", id, true)
	for id: String in _achievement_counters:
		config.set_value("counters", id, _achievement_counters[id])
	config.save(ACHIEVEMENTS_PATH)


# -------------------------------------------------------------------
# 区域设置 — 将内部语言代码映射到 Godot 区域设置并应用
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# 区域设置框架 — 可扩展到任何语言
# -------------------------------------------------------------------

## 支持的区域设置有序列表。在此添加新语言。
const SUPPORTED_LOCALES: Array[String] = ["zh", "en"]

## 每个区域设置的人类可读标签（显示在设置 UI 中）。
const LOCALE_LABELS: Dictionary = {
	"zh": "简体中文",
	"en": "ENGLISH",
}

func get_locale() -> String:
	return _settings.language.to_lower()

## 检查活动区域设置是否匹配给定代码（前缀匹配）。
func is_locale(code: String) -> bool:
	return TranslationServer.get_locale().begins_with(code)

## 从区域设置->文本字典获取显示文本。
## 回退顺序：请求的区域设置 -> "en" -> 第一个可用值。
func localized(dict: Dictionary) -> String:
	var loc: String = get_locale()
	if dict.has(loc):
		return dict[loc]
	if dict.has("en"):
		return dict["en"]
	for key in dict:
		return dict[key]
	return ""

## 循环到下一个支持的区域设置。
func next_locale() -> String:
	var cur: String = get_locale()
	var idx: int = SUPPORTED_LOCALES.find(cur)
	if idx < 0:
		return SUPPORTED_LOCALES[0]
	return SUPPORTED_LOCALES[(idx + 1) % SUPPORTED_LOCALES.size()]

func _apply_locale() -> void:
	var loc: String = _settings.language.to_lower()
	TranslationServer.set_locale(loc)
	ProjectSettings.set_setting("internationalization/locale/locale", loc)
	# 仅加载活动区域设置的翻译
	_switch_translation(loc)


var _active_translation: Translation = null

## 移除之前加载的任何翻译，然后仅加载 @p_locale 的翻译。
## 这确保 tr() 永远不会从错误的语言文件返回 msgstr。
func _switch_translation(p_locale: String) -> void:
	# 移除之前激活的翻译（如果有）
	if _active_translation:
		TranslationServer.remove_translation(_active_translation)
		_active_translation = null

	# 加载正确的 .po 文件
	var po_path: String = "res://locale/" + p_locale + ".po"
	if not ResourceLoader.exists(po_path):
		push_warning("GameManager: Translation file not found — ", po_path)
		return

	var tl: Translation = load(po_path) as Translation
	if tl:
		tl.locale = p_locale
		TranslationServer.add_translation(tl)
		_active_translation = tl


func _generate_id() -> String:
	return str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)


# ===================================================================
# 字体回退 — 确保每个字符都能用字形渲染。
# 英文字体（times、TCM、timesi）缺少 CJK 字形；中文字体
# （SourceHanSerif、simfang）包含拉丁字形，因此 CJK 字体
# 用作通用回退。主字体中找不到的字符用 [font=...][/font] BBCode 包裹。
# ===================================================================

const CJK_RANGES: Array[Dictionary] = [
	{"lo": 0x4E00, "hi": 0x9FFF},  # CJK Unified
	{"lo": 0x3400, "hi": 0x4DBF},  # CJK Ext-A
	{"lo": 0x3000, "hi": 0x303F},  # CJK punctuation
	{"lo": 0xFF00, "hi": 0xFFEF},  # Fullwidth forms
	{"lo": 0x3040, "hi": 0x309F},  # Hiragana
	{"lo": 0x30A0, "hi": 0x30FF},  # Katakana
]

## 检查字符是否落在拉丁字体缺少的 CJK 范围内。
static func _is_cjk(ch: String) -> bool:
	if ch.length() != 1:
		return false
	var c: int = ch.unicode_at(0)
	for r in CJK_RANGES:
		if c >= r.lo and c <= r.hi:
			return true
	return false


## 当 `font_path` 处的字体已知包含 CJK 字形时返回 true。
static func _font_has_cjk(font_path: String) -> bool:
	return font_path in [FONT_ZH_BODY, FONT_ZH_TITLE, FONT_ZH_EMPHASIS]


## 将主字体无法渲染的连续字符用
## [font=fallback_path][/font] BBCode 标签包裹。
## @param text          原始文本（可能已包含 BBCode 标签）。
## @param primary_path  主字体路径（例如 FONT_EN_BODY）。
## @param fallback_path 回退字体路径（例如 FONT_ZH_BODY）。
func wrap_font_fallback(text: String, primary_path: String, fallback_path: String) -> String:
	if text.is_empty():
		return text
	# 如果主字体已覆盖 CJK，无需回退
	if _font_has_cjk(primary_path):
		return text
	if primary_path == fallback_path:
		return text

	var needs_fallback: bool = false
	for ch in text:
		if _is_cjk(ch):
			needs_fallback = true
			break
	if not needs_fallback:
		return text

	# 构建输出 — 将 CJK 连续字符用 [font=fallback]...[/font] 包裹
	var result: String = ""
	var in_fallback: bool = false
	var i: int = 0
	while i < text.length():
		# 跳过已有的 BBCode 标签 — 保持原样传递
		if text[i] == "[":
			var close: int = text.find("]", i)
			if close > i:
				if in_fallback:
					result += "[/font]"
					in_fallback = false
				result += text.substr(i, close - i + 1)
				i = close + 1
				continue

		var ch: String = text[i]
		if _is_cjk(ch):
			if not in_fallback:
				result += "[font=" + fallback_path + "]"
				in_fallback = true
			result += ch
		else:
			if in_fallback:
				result += "[/font]"
				in_fallback = false
			result += ch
		i += 1

	if in_fallback:
		result += "[/font]"

	return result


# ===================================================================
# 字体辅助 — 返回给定区域设置 + 样式的最佳可用字体。
# ===================================================================

enum FontStyle { BODY, TITLE, EMPHASIS }

## 返回给定样式下 @p_text 的最佳字体路径。
## 如果文本包含任何 CJK 字符，无论区域设置如何，始终返回
## 支持 CJK 的字体，因为拉丁字体（TCM / times）缺少
## CJK 字形，会渲染为空白方块。纯拉丁文本使用
## 区域设置对应的字体。
static func font_for_text(p_text: String, p_style: FontStyle) -> String:
	var need_cjk: bool = false
	for ch in p_text:
		if _is_cjk(ch):
			need_cjk = true
			break

	# CJK text → always use a CJK-capable font (SourceHanSerif / simfang)
	if need_cjk:
		match p_style:
			FontStyle.BODY:    return FONT_ZH_BODY
			FontStyle.TITLE:   return FONT_ZH_TITLE
			FontStyle.EMPHASIS: return FONT_ZH_EMPHASIS
			_:                 return FONT_ZH_BODY

	# Pure Latin text → locale-appropriate font
	var is_zh: bool = TranslationServer.get_locale().begins_with("zh")
	match p_style:
		FontStyle.BODY:
			return FONT_ZH_BODY if is_zh else FONT_EN_BODY
		FontStyle.TITLE:
			return FONT_ZH_TITLE if is_zh else FONT_TCM
		FontStyle.EMPHASIS:
			return FONT_ZH_EMPHASIS if is_zh else FONT_EN_EMPHASIS
		_:
			return FONT_ZH_BODY


## 便捷方法：根据文本内容选择正确的预加载字体。
## 当 @p_text 包含任何 CJK 字符时返回 @p_font_zh（拉丁字体
## 缺少 CJK 字形，会渲染为空白方块）。否则基于区域设置选择。
static func select_font(p_text: String, p_font_zh: Font, p_font_en: Font) -> Font:
	if not p_text.is_empty():
		for ch in p_text:
			if _is_cjk(ch):
				return p_font_zh
	var is_zh: bool = TranslationServer.get_locale().begins_with("zh")
	return p_font_zh if is_zh else p_font_en


## 便捷方法：根据文本内容选择字体大小。
## CJK 文本适合稍小的字号；拉丁文本适合较大的字号。
## 当 @p_text 包含任何 CJK 字符时返回 @p_size_zh，否则返回 @p_size_en。
static func select_font_size(p_text: String, p_size_zh: int, p_size_en: int) -> int:
	if not p_text.is_empty():
		for ch in p_text:
			if _is_cjk(ch):
				return p_size_zh
	return p_size_en
# ── 共享 UI 工具 ─────────────────────────────────────────

## 标准子场景入场动画 — modulate + scale 淡入。
## 供 LoadScene / MusicGallery / SceneGallery / SettingsScene 统一使用。
static func animate_scene_enter(target: Control) -> void:
	target.modulate.a = 0.0
	target.scale = Vector2(0.98, 0.98)
	var tw := target.create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(target, "modulate:a", 1.0, 0.8)
	tw.tween_property(target, "scale", Vector2(1.0, 1.0), 0.8)


## 原子化覆盖层状态：音频低通 + 共享背景模糊 + 变暗，三者必须同步。
## 供 VNInterface / SceneManager 统一调用，替代手动三连发射。
## 注意：SceneManager 中存在两处刻意的非原子调用（滑动错峰、Tab 重开保持
## 低通），那些位置不得改用本方法 — 见各自行内注释。
func set_overlay_mode(active: bool) -> void:
	AudioManager.set_menu_mode(active)
	EventBus.bg_blur_toggle.emit(active)
	EventBus.bg_darken_toggle.emit(active)


# ===================================================================
# 持久化变量 — 跨所有存档的账号级标记（成就触发等）
# ===================================================================

## 读取单个持久化变量，不存在返回 0。
@warning_ignore("shadowed_variable_base_class")
func get_persist_var(name: String) -> Variant:
	return _persist_vars.get(name, 0)


## ScriptContext 回调 — 当 @persist 写入时触发。
## 内部调用 _apply_persist_bridge 进行值变更守卫 + 持久化 + 桥接。
@warning_ignore("shadowed_variable_base_class")
func _on_persist_var_set(name: String, value: Variant) -> void:
	_apply_persist_bridge(name, value)


## 值变更守卫 + 持久化 + 成就桥接。
@warning_ignore("shadowed_variable_base_class")
func _apply_persist_bridge(name: String, value: Variant) -> void:
	# 值未变则跳过，防止重复触发（如重复 @persist 同一值）
	var old: Variant = _persist_vars.get(name)
	if old != null and old == value:
		return

	_persist_vars[name] = value
	_save_persist_vars()

	# 成就桥接：ach_<成就ID> = true → 解锁对应成就
	if name.begins_with("ach_"):
		var achievement_id: String = name.trim_prefix("ach_")
		if not achievement_id.is_empty():
			unlock_achievement(achievement_id)


func _load_persist_vars() -> void:
	_persist_vars = {}
	var config := ConfigFile.new()
	if config.load(PERSIST_VARS_PATH) != OK:
		return
	for key: String in config.get_section_keys("vars"):
		_persist_vars[key] = config.get_value("vars", key)


func _save_persist_vars() -> void:
	var config := ConfigFile.new()
	for key: String in _persist_vars:
		config.set_value("vars", key, _persist_vars[key])
	config.save(PERSIST_VARS_PATH)
