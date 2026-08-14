## PlotData : Resource
## 包含完整解析的剧情脚本，包含角色、标题和节点序列。
class_name PlotData extends Resource

@export var id: String = ""
@export var title: LocText
@export var characters: Dictionary = {}
@export var nodes: Array[PlotNode] = []

## label 名 → node_index 的快速查找表（解析期填入）
@export var labels: Dictionary = {}


@warning_ignore("unused_parameter")
func get_character_name(who: String, language: String) -> String:
	if who.is_empty():
		return ""
	if who == "player":
		return GameManager.player_name if not GameManager.player_name.is_empty() else who
	var char_data: LocText = characters.get(who, null)
	if char_data:
		return char_data.ZH if GameManager.is_locale("zh") else char_data.EN
	return who
