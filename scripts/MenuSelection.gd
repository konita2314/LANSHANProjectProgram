## MenuSelection : RefCounted
## 菜单选中状态机 — 纯逻辑，无场景树依赖，可单元测试。
## wrap=true 时循环环绕（MainMenu 6 项）；wrap=false 时边界钳制（QuitModal 0/1）。
## 同时跟踪上一次已应用焦点的索引：-1 表示下次 apply_focus 需要全量刷新。
class_name MenuSelection
extends RefCounted

var _item_count: int = 0
var _wrap: bool = false
var _selected_index: int = 0
var _previous_focus_index: int = -1


func _init(p_item_count: int, p_wrap: bool, p_initial_index: int = 0) -> void:
	_item_count = p_item_count
	_wrap = p_wrap
	_selected_index = clampi(p_initial_index, 0, maxi(_item_count - 1, 0))


func get_item_count() -> int:
	return _item_count


func get_selected() -> int:
	return _selected_index


func get_previous_focus() -> int:
	return _previous_focus_index


## 按方向移动选中项。wrap 模式循环环绕，非 wrap 模式钳制在 [0, count-1]。
## 选中发生变化才返回 true（调用方据此决定是否刷新焦点/播放音效）。
func move(direction: int) -> bool:
	if _item_count <= 0:
		return false
	var new_index: int
	if _wrap:
		new_index = (_selected_index + direction + _item_count) % _item_count
	else:
		new_index = clampi(_selected_index + direction, 0, _item_count - 1)
	if new_index == _selected_index:
		return false
	_selected_index = new_index
	return true


## 直接选中指定索引（钳制）。选中发生变化才返回 true。
func select(index: int) -> bool:
	if _item_count <= 0:
		return false
	var clamped: int = clampi(index, 0, _item_count - 1)
	if clamped == _selected_index:
		return false
	_selected_index = clamped
	return true


## 清除焦点历史 — 下次 apply_focus 全量刷新（首次聚焦、模态开/关后、重进场景时调用）。
func reset_focus_history() -> void:
	_previous_focus_index = -1


## 焦点已应用完毕 — 记录当前选中项，使后续 apply_focus 仅 tween 上一项与新项。
func mark_focus_applied() -> void:
	_previous_focus_index = _selected_index
