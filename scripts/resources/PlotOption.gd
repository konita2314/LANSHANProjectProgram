## PlotOption : Resource
## 选择节点中的单个选项。
class_name PlotOption extends Resource

@export var ZH: String = ""
@export var EN: String = ""
@export var target_node: int = -1
@export var target_plot_id: String = ""
@export var target_node_index: int = -1

## 当为 true 时，在反应节点完成后循环回选择节点，
## 让玩家重新选择。由 _rechoose 目标或 @rechoose 命令设置。
@export var rechoose: bool = false

## 选择此选项时立即播放的反应节点。
## 插入在选择节点之后、主剧情继续之前。
## 空数组 = 无反应（直接跳转或继续）。
@export var reaction_nodes: Array[PlotNode] = []

## 选择此选项时执行的表达式列表。
## 每项是原始表达式字符串，如 "affection += 10"、"flag = true"。
## 由 ScriptContext.apply_expression() 在运行时解析执行。
@export var actions: Array[String] = []
