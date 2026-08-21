class_name FrameAnimator
extends Node
## 帧动画组件 — 管理角色的预览帧加载和播放
## 从 GameManager 的角色帧目录加载 walk/idle 帧序列
## 供 player.gd 和 npc_base.gd 复用，避免重复代码

signal animation_setup_complete  ## 帧加载完成信号

const DIRECTIONS := ["down", "up", "left", "right"]
const DEFAULT_WALK_FPS: float = 7.0
const DEFAULT_IDLE_FPS: float = 6.0

var walk_fps: float = DEFAULT_WALK_FPS
var idle_fps: float = DEFAULT_IDLE_FPS

var _walk_frames: Dictionary = {}
var _idle_frames: Dictionary = {}
var _using_preview_frames: bool = false
var _anim_timer: float = 0.0
var _current_direction: String = "down"
var _canvas_size: Vector2 = Vector2.ZERO
var _baseline_y: float = 0.0
var _preview_scale: float = 1.0

var sprite: Sprite2D = null  ## 需要由使用者设置
var default_sprite_position: Vector2 = Vector2.ZERO
var default_sprite_scale: Vector2 = Vector2.ONE
var default_sprite_centered: bool = true
var _texture_override: Texture2D = null

## 初始化：加载指定角色的预览帧
## [param char_id] 角色 ID（如 "sister"、"cool_npc"）
## [param p_sprite] 要控制的 Sprite2D
func setup(char_id: String, p_sprite: Sprite2D) -> void:
	sprite = p_sprite
	if sprite:
		default_sprite_position = sprite.position
		default_sprite_scale = sprite.scale
		default_sprite_centered = sprite.centered
	_load_frames(char_id)
	_update_animation(0.0, false)

## 设置纹理覆盖（用于特殊效果，如手电筒光斑等）
func set_texture_override(texture: Texture2D) -> void:
	_texture_override = texture
	if not sprite or texture == null:
		return
	_apply_default_layout()
	sprite.texture = texture

## 清除纹理覆盖，恢复帧动画
func clear_texture_override() -> void:
	_texture_override = null
	if _using_preview_frames:
		_apply_preview_layout()
	else:
		_apply_default_layout()
	_update_animation(0.0, false)

## 每帧更新动画（在 _physics_process 或 _process 中调用）
## [param delta] 帧间隔
## [param moving] 是否正在移动
## [param facing] 当前朝向向量
## [param running] 是否跑步（影响帧率）
func update(delta: float, moving: bool, facing: Vector2, running: bool = false) -> void:
	if _texture_override != null:
		if sprite:
			sprite.texture = _texture_override
		return
	_update_facing(facing)
	_update_animation(delta, moving, running)

## 更新朝向（翻转 sprite）
func _update_facing(facing: Vector2) -> void:
	if not sprite or _using_preview_frames:
		return
	if facing.x < 0:
		sprite.flip_h = true
	elif facing.x > 0:
		sprite.flip_h = false

## 更新帧动画
func _update_animation(delta: float, moving: bool, running: bool = false) -> void:
	if not sprite:
		return
	if _texture_override != null:
		sprite.texture = _texture_override
		return
	if not _using_preview_frames:
		return

	var direction := _get_direction_name(Vector2.DOWN)  # 默认
	if sprite.get_parent() and "facing_direction" in sprite.get_parent():
		direction = _get_direction_name(sprite.get_parent().facing_direction)

	if direction != _current_direction:
		_current_direction = direction
		_anim_timer = 0.0

	if moving:
		var frames: Array[Texture2D] = _walk_frames.get(direction, [])
		if frames.is_empty():
			return
		var fps = walk_fps * (1.5 if running else 1.0)
		_anim_timer += delta * fps
		sprite.texture = frames[int(floor(_anim_timer)) % frames.size()]
	else:
		_anim_timer = 0.0
		var idle_texture: Texture2D = _idle_frames.get(direction, null)
		if idle_texture:
			sprite.texture = idle_texture

## 根据朝向向量获取方向名称
func _get_direction_name(facing: Vector2) -> String:
	if absf(facing.x) > absf(facing.y):
		return "right" if facing.x > 0.0 else "left"
	return "down" if facing.y >= 0.0 else "up"

## 是否已加载预览帧
func is_using_preview_frames() -> bool:
	return _using_preview_frames

# ====== 内部方法 ======

## 从角色帧目录加载 walk/idle 帧序列并应用预览布局。
## [param char_id] 角色ID。
func _load_frames(char_id: String) -> void:
	var base_dir := _get_export_dir(char_id)
	if base_dir.is_empty():
		return
	var walk_dir := base_dir.path_join("walk")
	var idle_dir := base_dir.path_join("idle")
	var manifest := _load_manifest(base_dir.path_join("manifest.json"))
	if manifest.is_empty():
		return

	var loaded_walk: Dictionary = {}
	var loaded_idle: Dictionary = {}
	var first_frame_texture: Texture2D = null
	for direction in DIRECTIONS:
		var direction_frames: Array[Texture2D] = []
		for frame_index in range(4):
			var frame_path := walk_dir.path_join("%s_%d.png" % [direction, frame_index])
			var frame_texture := _load_texture(frame_path)
			if frame_texture == null:
				return
			if first_frame_texture == null:
				first_frame_texture = frame_texture
			direction_frames.append(frame_texture)
		var idle_texture := _load_texture(idle_dir.path_join("idle_%s.png" % direction))
		if idle_texture == null:
			return
		loaded_walk[direction] = direction_frames
		loaded_idle[direction] = idle_texture

	if first_frame_texture == null:
		return
	_canvas_size = Vector2(
		float(manifest.get("canvas_width", first_frame_texture.get_width())),
		float(manifest.get("canvas_height", first_frame_texture.get_height()))
	)
	_baseline_y = float(manifest.get("baseline_y", _canvas_size.y))
	if _baseline_y <= 0.0:
		_baseline_y = _canvas_size.y
	_preview_scale = GameManager.get_character_visual_height(char_id) / _baseline_y
	_walk_frames = loaded_walk
	_idle_frames = loaded_idle
	_using_preview_frames = true
	_apply_preview_layout()
	animation_setup_complete.emit()

## 获取角色帧导出目录（需存在 manifest.json）。
## [param char_id] 角色ID。
## [return] 目录路径，不存在时为空字符串。
func _get_export_dir(char_id: String) -> String:
	var res_dir := GameManager.get_character_frames_root(char_id)
	if not res_dir.is_empty() and ResourceLoader.exists(res_dir.path_join("manifest.json")):
		return res_dir
	return ""

## 加载指定路径的纹理资源。
## [param path] 纹理路径。
## [return] 纹理，不存在时为 null。
func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)

## 读取并解析 manifest.json 清单。
## [param path] 清单文件路径。
## [return] 解析后的字典，失败时为空字典。
func _load_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file_text := FileAccess.get_file_as_string(path)
	if file_text.is_empty():
		return {}
	var parsed = JSON.parse_string(file_text)
	if parsed is Dictionary:
		return parsed
	return {}

## 按 manifest 的画布尺寸与基线应用预览帧布局。
func _apply_preview_layout() -> void:
	if not sprite:
		return
	if _canvas_size == Vector2.ZERO or _baseline_y <= 0.0:
		return
	sprite.centered = false
	sprite.flip_h = false
	sprite.scale = Vector2.ONE * _preview_scale
	sprite.position = Vector2(-_canvas_size.x * 0.5 * _preview_scale, -_baseline_y * _preview_scale)

## 恢复使用者设置的默认 Sprite 布局。
func _apply_default_layout() -> void:
	if not sprite:
		return
	sprite.centered = default_sprite_centered
	sprite.scale = default_sprite_scale
	sprite.position = default_sprite_position
