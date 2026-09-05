## PlotNode : Resource
## 视觉小说剧情中的单个节点 — 对话、旁白、选择或场景命令。
class_name PlotNode extends Resource

## 谁在说话（"" 表示旁白，"???" 表示未知）
@export var who: String = ""

## 中文文本
@export var ZH: String = ""

## 英文文本
@export var EN: String = ""

## 背景图片路径（粘性 — 持续到更改为止）
@export var bg: String = ""

## 当前地点（@locate 指令参数 — 地图地点名；状态实际存于存档作用域变量，天然粘性）
@export var location: String = ""

## 背景对齐："" = 居中, "up" = 顶部对齐, "down" = 底部对齐
@export var bg_align: String = ""

## 角色精灵路径（null = 清除角色，empty = 不变）
@export var ch: String = ""

## 可选注释/注解
@export var note: String = ""

## 启用故障视觉效果
@export var glitch: bool = false

## 节点类型："text"、"select" 或 "scene"
@export var type: String = "text"

## 选择选项（仅适用于类型 "select"）
@export var options: Array[PlotOption] = []

## 音频命令（旧格式）
@export var audio: AudioCommand = null

## BGM 命令
@export var bgm: AudioCommand = null

## SFX 命令 — 长电影音效
@export var sfx: AudioCommand = null

## SFX 短命令 — 一次性短音效（独立播放器，从不阻塞长 SFX）
@export var sfx_short: AudioCommand = null

## 要过渡到的下一个场景（仅适用于类型 "scene"）
@export var next_scene: String = ""

## 等待时间（秒）（0 = 不等待，来自 @wait 命令）
@export var wait_time: float = 0.0


## 章节标题显示
@export var chapter: LocText = null

## 停止过渡 — 暂时隐藏对话框、名称框和角色
@export var stop_transition: bool = false

## 环境音命令（环境循环音层）
@export var ambience: AudioCommand = null

## BGM 仅淡出标志 — 淡出 BGM 而不启动新曲目（秒）
@export var fade_out_bgm: float = 0.0

## 淡入黑屏：持续时间（秒）（>0 触发淡入黑屏覆盖动画）。
@export var fade_black: float = 0.0

## 重新选择 — 当为 true 时，跳回最近的选择节点
## 并让玩家重新选择。由 @rechoose 命令使用。
@export var rechoose: bool = false

## 支线故事结束 — 发出 back_requested 信号返回上一级菜单。由 @end 命令设置。
@export var end_story: bool = false

## 段落结束请求包 — 由 @return / @title 解析产生，
## 段落收尾时经 VNInterface.return_request() 打包发给 FlowManager 分派。
## 形如 {"type": "load_plot", "plot_id": "chapter1", "node_index": 0}；
## 空字典表示本节点不是请求节点。
@export var request: Dictionary = {}

# ── V2 流程控制字段 ──

## type="label" 时的锚点名称
@export var label: String = ""

## type="goto" 时的目标 label 名（解析期填入，运行时由 jump_to 替代）
@export var goto_label: String = ""

## 表达式字符串 — type="set" 时是赋值表达式（如 "affection += 10"），
## type="if" 时是条件表达式（如 "affection >= 50"）。统一走 ScriptExpression。
@export var expression: String = ""

## 通用跳转目标 node_index
## - type="if": 条件为 false 时跳到这里
## - type="else": 无条件跳到这里（到 endif）
## - type="goto": label 解析后填入的目标 index
@export var jump_to: int = -1

## 源文件行号，用于错误定位
@export var line_number: int = 0
