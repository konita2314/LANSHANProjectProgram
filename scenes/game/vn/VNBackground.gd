## VNBackground : Control
## 双层背景，支持 A/B 交叉淡入淡出、鼠标视差，以及竖屏图片的上下对齐。
class_name VNBackground
extends Control

# ---------------------------------------------------------------------------
# 双层背景
# ---------------------------------------------------------------------------
var _layer_a: TextureRect
var _layer_b: TextureRect
var _active_layer: TextureRect
var _inactive_layer: TextureRect
var _current_bg: String = ""
var _crossfade_tween: Tween = null

# ---------------------------------------------------------------------------
# 黑色叠加层
# ---------------------------------------------------------------------------
var _black_overlay: ColorRect
var _black_tween: Tween = null

# ---------------------------------------------------------------------------
# 对齐状态
# ---------------------------------------------------------------------------
var _current_align: String = ""            # "" / "up" / "down"
var _base_position: Vector2 = Vector2.ZERO  # 基础位置（不含视差偏移）
var _align_tween: Tween = null

# ---------------------------------------------------------------------------
# 视差状态
# ---------------------------------------------------------------------------
var _mouse_pos: Vector2 = Vector2.ZERO
var _parallax_target: Vector2 = Vector2.ZERO
const PARALLAX_RANGE: float = 37.5
const PARALLAX_SPEED: float = 900.0
var _viewport_size: Vector2 = Vector2.ZERO
var _setup_done: bool = false

## 跳过/自动模式标志 — 为 true 时跳过对齐动画
var _skip_mode: bool = false


# ===================================================================
# 生命周期
# ===================================================================

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

	_layer_a = _make_layer()
	_layer_b = _make_layer()
	_layer_b.modulate.a = 0.0
	_active_layer = _layer_a
	_inactive_layer = _layer_b

	_black_overlay = ColorRect.new()
	_black_overlay.color = Color.BLACK
	_black_overlay.modulate.a = 0.0
	_black_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_black_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black_overlay)


func _make_layer() -> TextureRect:
	@warning_ignore("shadowed_variable_base_class")
	var tr := TextureRect.new()
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	tr.layout_mode = 0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(tr)
	move_child(tr, 0)
	return tr


# ===================================================================
# 公共 API — 背景切换
# ===================================================================

## 设置背景图像，可指定对齐方式。
func set_bg(path: String, align: String = "") -> void:
	var normalized: String = _normalize_path(path)
	if normalized == _current_bg and align == _current_align:
		return

	var texture: Texture2D = _load_texture(normalized)
	if not texture:
		# 仅对齐变更（无新纹理）
		if align != _current_align:
			_apply_alignment(align)
		return

	_current_bg = normalized
	_kill_crossfade()
	_kill_black_tween()
	_black_overlay.modulate.a = 0.0  # 新背景载入时清除黑幕

	_inactive_layer.texture = texture
	_apply_parallax_sizing(_inactive_layer)
	_apply_alignment_to_layer(_inactive_layer, align)
	_clamp_layer_position(_inactive_layer)
	_inactive_layer.modulate.a = 0.0

	_crossfade_tween = create_tween().set_parallel(true)
	_crossfade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_crossfade_tween.tween_property(_active_layer, "modulate:a", 0.0, 1.2)
	_crossfade_tween.tween_property(_inactive_layer, "modulate:a", 1.0, 1.2)

	var prev: TextureRect = _active_layer
	_active_layer = _inactive_layer
	_inactive_layer = prev

	_current_align = align
	_base_position = _inactive_layer.position


## 立即设置背景（无交叉淡入淡出），用于场景切换时防止旧背景残留。
func set_bg_immediate(path: String, align: String = "") -> void:
	var normalized: String = _normalize_path(path)
	if normalized == _current_bg and align == _current_align:
		return
	var texture: Texture2D = _load_texture(normalized)
	if not texture:
		return
	_current_bg = normalized
	_current_align = align
	_kill_crossfade()
	_kill_black_tween()
	_black_overlay.modulate.a = 0.0
	_active_layer.texture = texture
	_active_layer.modulate.a = 1.0
	_inactive_layer.texture = null
	_inactive_layer.modulate.a = 0.0
	_apply_parallax_sizing(_active_layer)
	_apply_alignment_to_layer(_active_layer, align)
	_clamp_layer_position(_active_layer)
	_base_position = _active_layer.position


## 仅更改当前背景的对齐方式（不换纹理）。
func set_align(align: String) -> void:
	if align == _current_align:
		return
	if align != "" and align != "up" and align != "down":
		return
	_current_align = align
	_apply_alignment(align)


## 设置跳过模式 — 对齐移动变为瞬间完成。
func set_skip_mode(skip: bool) -> void:
	_skip_mode = skip
	if skip and _align_tween and _align_tween.is_valid():
		_align_tween.kill()
		_align_tween = null


# ===================================================================
# 对齐
# ===================================================================

func _apply_alignment(align: String) -> void:
	var target: Vector2 = _calc_align_position(align)
	if _base_position == target:
		return

	_kill_align_tween()
	if _skip_mode:
		_base_position = target
		_active_layer.position = _base_position
		return

	_align_tween = create_tween()
	_align_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_align_tween.tween_method(_set_base_position, _base_position, target, 0.6)


func _apply_alignment_to_layer(layer: TextureRect, align: String) -> void:
	layer.position = _calc_align_position(align)


func _calc_align_position(align: String) -> Vector2:
	if _viewport_size.x <= 0:
		return Vector2.ZERO
	var cx: float = -(_viewport_size.x * 0.09)
	var cy: float = -(_viewport_size.y * 0.09)
	var lh: float = _viewport_size.y * 1.18
	match align:
		"up":   return Vector2(cx, 0.0)
		"down": return Vector2(cx, _viewport_size.y - lh)
		_:      return Vector2(cx, cy)


func _set_base_position(v: Vector2) -> void:
	_base_position = v


func _kill_align_tween() -> void:
	if _align_tween and _align_tween.is_valid():
		_align_tween.kill()
	_align_tween = null


# ===================================================================
# 视差
# ===================================================================

func update_parallax(mouse_pos: Vector2, viewport_size: Vector2, delta: float) -> void:
	_mouse_pos = mouse_pos
	_viewport_size = viewport_size

	if not _setup_done and viewport_size.x > 0:
		_setup_done = true
		_apply_parallax_sizing(_layer_a)
		_apply_parallax_sizing(_layer_b)
		_base_position = _calc_align_position(_current_align)
		_active_layer.position = _base_position
		_inactive_layer.position = _base_position
		_clamp_layer_position(_active_layer)
		_clamp_layer_position(_inactive_layer)

	if viewport_size.x <= 0:
		return

	var center: Vector2 = viewport_size / 2.0
	var ratio: Vector2 = (_mouse_pos - center) / center
	var para_offset: Vector2 = ratio * PARALLAX_RANGE
	_parallax_target = _base_position + para_offset

	# 根据对齐模式钳制视差目标，防止超出缓冲区露出黑边
	var layer_h: float = viewport_size.y * 1.18
	match _current_align:
		"up":   _parallax_target.y = minf(_parallax_target.y, 0.0)
		"down": _parallax_target.y = maxf(_parallax_target.y, viewport_size.y - layer_h)
		_:      _parallax_target.y = clampf(_parallax_target.y, viewport_size.y - layer_h, 0.0)

	_active_layer.position = _active_layer.position.move_toward(_parallax_target, PARALLAX_SPEED * delta)
	_inactive_layer.position = _inactive_layer.position.move_toward(_parallax_target, PARALLAX_SPEED * delta)

	# 硬边界守卫 — 与 Map._clamp_pan 逻辑一致：图片边缘永不超过屏幕边缘
	_clamp_layer_position(_active_layer)
	_clamp_layer_position(_inactive_layer)


func _apply_parallax_sizing(layer: TextureRect) -> void:
	var vs: Vector2 = _viewport_size
	if vs.x <= 0:
		return
	var overscan: Vector2 = vs * 0.18
	layer.size = vs + overscan


## 硬边界守卫：确保 layer 边缘永不超过屏幕边缘。
## 与 Map._guard_pan_bounds 逻辑一致。
func _clamp_layer_position(layer: TextureRect) -> void:
	var clip_w: float = _viewport_size.x
	var clip_h: float = _viewport_size.y
	if clip_w <= 0 or clip_h <= 0:
		return
	var layer_w: float = clip_w * 1.18
	var layer_h: float = clip_h * 1.18
	layer.position.x = clampf(layer.position.x, clip_w - layer_w, 0.0)
	layer.position.y = clampf(layer.position.y, clip_h - layer_h, 0.0)


func _kill_crossfade() -> void:
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	_crossfade_tween = null


func _normalize_path(path: String) -> String:
	if path.is_empty(): return path
	var normalized: String = AssetResolver.normalize_web_path(path)
	if normalized.begins_with("res://"): return normalized
	if not "/" in normalized:
		var resolved: String = AssetResolver.resolve_bg(normalized)
		if resolved != normalized and ResourceLoader.exists(resolved):
			return resolved
	return normalized


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res := load(path)
	if res is Texture2D:
		return res
	return null


# ===================================================================
# 重置 & 清除
# ===================================================================

func reset() -> void:
	_kill_crossfade()
	_kill_align_tween()
	_current_bg = ""
	_current_align = ""
	_base_position = Vector2.ZERO
	_active_layer.texture = null
	_active_layer.modulate.a = 1.0
	_inactive_layer.texture = null
	_inactive_layer.modulate.a = 0.0


func clear_bg() -> void:
	_kill_crossfade()
	_kill_align_tween()
	_current_bg = ""
	_current_align = ""
	_base_position = Vector2.ZERO
	_active_layer.texture = null
	_inactive_layer.texture = null
	_active_layer.modulate.a = 1.0
	_inactive_layer.modulate.a = 0.0


# ===================================================================
# 场景过渡 — 淡入/淡出黑色
# ===================================================================

func fade_to_black(duration: float = 1.0) -> void:
	_kill_black_tween()
	_black_tween = create_tween()
	_black_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_black_tween.tween_property(_black_overlay, "modulate:a", 1.0, duration)


func fade_from_black(duration: float = 1.0) -> void:
	_kill_black_tween()
	_black_tween = create_tween()
	_black_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_black_tween.tween_property(_black_overlay, "modulate:a", 0.0, duration)


func set_black() -> void:
	_kill_black_tween()
	_black_overlay.modulate.a = 1.0


func _kill_black_tween() -> void:
	if _black_tween and _black_tween.is_valid():
		_black_tween.kill()
	_black_tween = null
