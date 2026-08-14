## AudioCommand : Resource
## 描述剧情节点内的音频播放/停止命令。
class_name AudioCommand extends Resource

@export var play: String = ""
@export var stop: bool = false
@export var loop: bool = false
@export var audio_type: String = ""

## 交叉淡入淡出持续时间 — 当 > 0 时，使用交叉淡入淡出而非立即切换。
## fade_out 是淡出当前 BGM 的持续时间，fade_in 是新曲目的淡入时间。
@export var crossfade: bool = false
@export var fade_out_duration: float = 1.5
@export var fade_in_duration: float = 1.5

## 仅淡出模式：设置后，淡出当前 BGM 而不启动新曲目。
@export var fade_out_only: bool = false

## 环境音层音量（0.0–1.0），在 audio_type == "ambience" 时使用。
@export var ambience_volume: float = 0.5
