## AppSettings : Resource
## 应用程序范围的语言、音频、显示和游戏设置。
class_name AppSettings extends Resource

@export var language: String = "ZH"
@export var text_speed: String = "normal"
@export var master_volume: float = 1.0
@export var bgm_volume: float = 0.7
@export var sfx_volume: float = 0.8
@export var ambience_volume: float = 0.5
@export var auto_play: bool = false
@export var quality: String = "high"
@export var display_mode: String = "windowed"
@export var framerate: String = "vsync"


## 用 key 字符串读取设置值（供数据驱动的 SettingsScene 使用）。
func get_prop(key: String) -> Variant:
	match key:
		"language": return language
		"text_speed": return text_speed
		"master_volume": return master_volume
		"bgm_volume": return bgm_volume
		"sfx_volume": return sfx_volume
		"ambience_volume": return ambience_volume
		"auto_play": return auto_play
		"quality": return quality
		"display_mode": return display_mode
		"framerate": return framerate
	return null


func get_default() -> AppSettings:
	var settings := AppSettings.new()
	settings.language = "ZH"
	settings.text_speed = "normal"
	settings.master_volume = 1.0
	settings.bgm_volume = 0.7
	settings.sfx_volume = 0.8
	settings.ambience_volume = 0.5
	settings.auto_play = false
	settings.quality = "high"
	settings.display_mode = "windowed"
	settings.framerate = "vsync"
	return settings
