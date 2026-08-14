## SettingsRow : Control
## 设置行抽象基类 — 所有设置行类型（Slider、Cycle、未来 Toggle/KeyBind 等）的公共接口。
## SettingsScene 只通过基类方法与行交互，不做 `if row is SliderRow` 类型检查。
class_name SettingsRow
extends Control

## 行标识符（对应 _categories[].rows[].id）。
var row_id: String = ""

## 鼠标进入时发射，携带 row_id 供 SettingsScene 统一处理焦点。
@warning_ignore("unused_signal")
signal hovered(row_id: String)

## 语言 / 区域设置切换时调用。子类覆盖以更新所有显示文本。
@warning_ignore("unused_parameter")
func refresh_locale(data: Dictionary) -> void:
	pass

## 设置值变更后调用（例如在 _on_step_option 之后）。
## @param settings: 当前 AppSettings 实例
## @param display_text: 预计算的显示文本（来自 _get_option_display）
@warning_ignore("unused_parameter")
func refresh_value(settings: AppSettings, display_text: String) -> void:
	pass

## 键盘左/右键步进。子类覆盖：
##   - Slider: 调整 HSlider.value
##   - Cycle:  发射 stepped 信号
@warning_ignore("unused_parameter")
func step_value(delta: float) -> void:
	pass
