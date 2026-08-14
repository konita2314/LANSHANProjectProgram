## EventBus : Node (Autoload)
## 场景间解耦通信的全局信号中心。
## 用法：EventBus.scene_changed.emit("TITLE")
extends Node

# --- 场景管理 ---
@warning_ignore("unused_signal")
signal scene_changed(scene_name: String)

# --- 游戏性 ---
# (plot_loaded, node_advanced, choice_made reserved for future use)

# --- 音频 ---
# (audio_unlock_requested reserved for future use)

# --- 存档/读档 ---
@warning_ignore("unused_signal")
signal game_saved(slot: int)
@warning_ignore("unused_signal")
signal game_loaded(slot: int)

@warning_ignore("unused_signal")
signal settings_changed(setting_name: String, value: Variant)
@warning_ignore("unused_signal")
signal shared_background_updated(bg_path: String)
@warning_ignore("unused_signal")
signal bg_blur_toggle(enable: bool)
@warning_ignore("unused_signal")
signal bg_darken_toggle(enable: bool)
@warning_ignore("unused_signal")
signal bg_set_black()
@warning_ignore("unused_signal")
signal bg_parallax_offset(x: float)

# --- 成就 ---
@warning_ignore("unused_signal")
signal achievement_unlocked(achievement_id: String)

# --- 教程提示 ---
@warning_ignore("unused_signal")
signal show_tips(pages: Array)

# --- VN 特定 ---
@warning_ignore("unused_signal")
signal terminal_status_changed(new_status: String)
@warning_ignore("unused_signal")
signal character_changed(character_path: String)
@warning_ignore("unused_signal")
signal background_changed(bg_path: String)
