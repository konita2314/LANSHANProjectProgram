## FlowManager : Node (Autoload)
## 全局剧情流主管 — 接收 VN 段落结束请求（return_request 信号包），
## 决定并执行后续走向：加载下一剧情、切换游戏内场景、返回标题。
## 剧本不再自行跳转（@jump 已移除），一切剧情走向均由本单例分派。
extends Node

# ── 主线游戏段落（含游戏内场景），按剧情推进顺序排列 ──
const MAIN_GAMEPART: Array[Dictionary] = [
	{"id": "RegistrationScene", "path": ""},
	{"id": "VN", "path": ""},
	{"id": "Map", "path": ""},
	{"id": "Operation1", "path": ""},
	{"id": "Operation2", "path": ""},
	{"id": "Operation3", "path": ""},
	{"id": "Operation4", "path": ""},
	{"id": "Operation5", "path": ""},
	{"id": "Operation6", "path": ""},
	{"id": "Operation7", "path": ""},
	{"id": "Operation8", "path": ""},
	{"id": "Operation9", "path": ""},
]

# ── 附属游戏段落 ──
const SUB_GAMEPART: Array[Dictionary] = [
	{"id": "MiniVN", "path": ""},
	{"id": "Tips", "path": ""},
]

# ── 主线剧情链（plot_id 与 VNInterface.STORY_TEXTS key 一致）──
const STORIES: Array[Dictionary] = [
	{"plot_id": "intro",    "path": "res://scripts/story/Intro/Intro.gd",            "next": "chapter1"},
	{"plot_id": "chapter1", "path": "res://scripts/story/Main/M1/Chapter_1.gd",       "next": "chapter2"},
	{"plot_id": "chapter2", "path": "res://scripts/story/Main/M2/Chapter_2.gd",       "next": "chapter3"},
	{"plot_id": "chapter3", "path": "res://scripts/story/Main/M3/Chapter_3.gd",       "next": "chapter4"},
	{"plot_id": "chapter4", "path": "res://scripts/story/Main/M4/Chapter_4.gd",       "next": ""},
]


## VNInterface.flow_return 信号回调（SceneManager 接线，bind VN 实例）。
## 请求包：{"requests": [...], "from_plot": ..., "node_index": ...}
func _on_flow_return(package: Dictionary, vn: VNInterface) -> void:
	# 守卫：VN 场景可能在请求送达前被销毁（异常退场等），丢弃并记录
	if not is_instance_valid(vn):
		push_warning("FlowManager: VN 实例已失效，丢弃请求包 — ", package)
		return

	var requests: Array[Dictionary] = package.get("requests", [])
	for req: Dictionary in requests:
		_execute_request(req, vn)


func _execute_request(request: Dictionary, vn: VNInterface) -> void:
	var req_type: String = request.get("type", "")
	match req_type:
		"load_plot":
			var plot_id: String = request.get("plot_id", "")
			var node_index: int = request.get("node_index", 0)
			if vn.has_method("execute_flow_load"):
				vn.execute_flow_load(plot_id, node_index)
			else:
				push_error("FlowManager: VN 场景缺少 execute_flow_load 方法，无法加载剧情 '", plot_id, "'")

		"goto_scene":
			var scene_name: String = request.get("scene", "")
			if scene_name.is_empty():
				push_error("FlowManager: goto_scene 请求缺少 scene 参数")
				return
			EventBus.scene_changed.emit(scene_name + "_FROM_JUMP")

		"back_to_title":
			EventBus.scene_changed.emit("TITLE")

		_:
			push_error("FlowManager: 未知请求类型 '", req_type, "'")
