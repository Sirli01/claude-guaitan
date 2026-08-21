extends Node
## 音频管理器 - BGM, SFX, 环境音管理

var bgm_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 8
var ui_click_sfx: AudioStream = null
var system_open_sfx: AudioStream = null
var pickup_sfx: AudioStream = null
var footstep_sfx: AudioStream = null
var door_open_sfx: AudioStream = null
var door_close_sfx: AudioStream = null

var is_silence_mode: bool = false  # 进入公寓后的死寂模式
var _bgm_tween: Tween = null  # 当前 BGM 淡入淡出 tween

# 位置音效对象池（避免频繁创建/销毁 AudioStreamPlayer2D）
const MAX_SFX_2D_POOL := 8
var _sfx_2d_pool: Array[AudioStreamPlayer2D] = []
var _sfx_2d_pool_index: int = 0

# BGM播放列表（自动轮播，曲间渐入渐出）
var _bgm_playlist: Array[AudioStream] = []
var _bgm_playlist_index: int = 0
var _bgm_playlist_pause: float = 3.0  # 曲间停顿秒数
var _bgm_playlist_fade: float = 1.5   # 渐变时长
var _bgm_playlist_active: bool = false

## 初始化：创建 BGM、环境音与 SFX 播放器池，并预加载常用音效。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_click_sfx = _load_optional_stream("res://assets/audio/sfx/ui_click.mp3")
	system_open_sfx = _load_optional_stream("res://assets/audio/sfx/system_open.mp3")
	pickup_sfx = _load_optional_stream("res://assets/audio/sfx/pickup.mp3")
	footstep_sfx = _load_optional_stream("res://assets/audio/sfx/footstep.mp3")
	door_open_sfx = _load_optional_stream("res://assets/audio/sfx/door_open.mp3")
	door_close_sfx = _load_optional_stream("res://assets/audio/sfx/door_close.mp3")
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "BGM"
	bgm_player.volume_db = -5.0
	add_child(bgm_player)
	
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = "Ambience"
	ambience_player.volume_db = -8.0
	add_child(ambience_player)
	
	for i in MAX_SFX_PLAYERS:
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

## 淡出旧 BGM 后切换到新曲目并淡入。
## [param stream] 要播放的新音频流。
## [param fade_duration] 淡出/淡入时长（秒）。
func play_bgm(stream: AudioStream, fade_duration: float = 1.0) -> void:
	if is_silence_mode:
		return
	# kill 上一次未完成的 tween，防止泄漏
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(bgm_player, "volume_db", -40.0, fade_duration)
	await _bgm_tween.finished
	bgm_player.stream = stream
	bgm_player.play()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(bgm_player, "volume_db", -5.0, fade_duration)

## 淡出并停止当前 BGM。
## [param fade_duration] 淡出时长（秒）。
func stop_bgm(fade_duration: float = 1.0) -> void:
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(bgm_player, "volume_db", -40.0, fade_duration)
	await _bgm_tween.finished
	bgm_player.stop()

## 从空闲的 SFX 播放器池中取一个播放器播放音效。
## [param stream] 要播放的音频流。
## [param volume_db] 播放音量（分贝）。
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return

## 尝试加载音频资源，路径不存在时不报错。
## [param path] 资源路径。
## [return] 加载到的 AudioStream；路径不存在时返回 null。
func _load_optional_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null

## 播放 UI 点击音效。
func play_ui_click(volume_db: float = -10.0) -> void:
	if ui_click_sfx:
		play_sfx(ui_click_sfx, volume_db)

## 播放打开系统界面（如暂停菜单）的音效。
func play_system_open(volume_db: float = -8.0) -> void:
	if system_open_sfx:
		play_sfx(system_open_sfx, volume_db)

## 播放拾取道具音效。
func play_pickup_sfx(volume_db: float = -6.0) -> void:
	if pickup_sfx:
		play_sfx(pickup_sfx, volume_db)

## 播放非定位的脚步声音效。
func play_footstep(volume_db: float = -12.0) -> void:
	if footstep_sfx:
		play_sfx(footstep_sfx, volume_db)

## 在指定世界坐标播放脚步声（带空间感）。
## [param pos] 世界坐标位置。
## [param volume_db] 播放音量（分贝）。
func play_footstep_at_position(pos: Vector2, volume_db: float = -14.0) -> void:
	if footstep_sfx:
		play_sfx_at_position(pos, footstep_sfx, volume_db)

## 播放开门音效。
func play_door_open(volume_db: float = -9.0) -> void:
	if door_open_sfx:
		play_sfx(door_open_sfx, volume_db)

## 播放关门音效。
func play_door_close(volume_db: float = -11.0) -> void:
	if door_close_sfx:
		play_sfx(door_close_sfx, volume_db)

## 递归遍历节点树，为所有未绑定的 BaseButton 自动挂接点击音效。
## [param root] 遍历起始节点。
func wire_button_clicks(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is BaseButton and not child.has_meta("ui_click_wired"):
			child.set_meta("ui_click_wired", true)
			if child is CheckButton:
				child.toggled.connect(_on_ui_toggle_changed)
			else:
				child.pressed.connect(_on_ui_button_pressed)
		wire_button_clicks(child)

## 按钮 pressed 信号回调：播放 UI 点击音效。
func _on_ui_button_pressed() -> void:
	play_ui_click()

## CheckButton toggled 信号回调：播放 UI 点击音效。
func _on_ui_toggle_changed(_on: bool) -> void:
	play_ui_click()

## 播放循环环境音。
## [param stream] 环境音音频流。
func play_ambience(stream: AudioStream) -> void:
	if is_silence_mode:
		return
	ambience_player.stream = stream
	ambience_player.play()

## 停止当前环境音。
func stop_ambience() -> void:
	ambience_player.stop()

## 进入死寂模式：立即停掉 BGM 与环境音，并屏蔽后续播放请求。
func enter_silence_mode() -> void:
	is_silence_mode = true
	stop_bgm(0.1)
	stop_ambience()

## 退出死寂模式，恢复正常播放。
func exit_silence_mode() -> void:
	is_silence_mode = false

## 停止全部 BGM、环境音与 SFX。
func stop_all() -> void:
	bgm_player.stop()
	ambience_player.stop()
	for player in sfx_players:
		player.stop()

# 播放一次性2D位置音效（有左右声道空间感，使用对象池）
## 在场景指定位置播放一次性 2D 定位音效（使用对象池复用播放器）。
## [param pos] 世界坐标位置。
## [param stream] 要播放的音频流。
## [param volume_db] 播放音量（分贝）。
func play_sfx_at_position(pos: Vector2, stream: AudioStream, volume_db: float = 0.0) -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		play_sfx(stream, volume_db)
		return
	# 获取或创建池中的 player
	var player2d: AudioStreamPlayer2D
	if _sfx_2d_pool.size() < MAX_SFX_2D_POOL:
		player2d = AudioStreamPlayer2D.new()
		player2d.bus = "SFX"
		player2d.max_distance = 800.0
		player2d.attenuation = 1.5
		tree.current_scene.add_child(player2d)
		_sfx_2d_pool.append(player2d)
	else:
		player2d = _sfx_2d_pool[_sfx_2d_pool_index]
		_sfx_2d_pool_index = (_sfx_2d_pool_index + 1) % MAX_SFX_2D_POOL
	player2d.stream = stream
	player2d.volume_db = volume_db
	player2d.global_position = pos
	player2d.play()

## ===== BGM 播放列表 =====
## 用法：AudioManager.play_playlist([bgm1, bgm2], 3.0, 2.0)
## 放完一首后停顿 pause 秒，渐入下一首，循环播放
func play_playlist(tracks: Array[AudioStream], pause: float = 3.0, fade: float = 1.5) -> void:
	_bgm_playlist = tracks
	_bgm_playlist_index = 0
	_bgm_playlist_pause = pause
	_bgm_playlist_fade = fade
	_bgm_playlist_active = true
	if not bgm_player.finished.is_connected(_on_playlist_track_finished):
		bgm_player.finished.connect(_on_playlist_track_finished)
	_play_playlist_current()

## 停止 BGM 播放列表轮播并清空队列。
## [param fade] 淡出时长（秒）。
func stop_playlist(fade: float = 1.0) -> void:
	_bgm_playlist_active = false
	_bgm_playlist.clear()
	stop_bgm(fade)

## 播放列表当前曲目（静音起播并渐入）。
func _play_playlist_current() -> void:
	if not _bgm_playlist_active or _bgm_playlist.is_empty():
		return
	if is_silence_mode:
		return
	var stream = _bgm_playlist[_bgm_playlist_index]
	bgm_player.stream = stream
	bgm_player.volume_db = -40.0
	bgm_player.play()
	var tw = create_tween()
	tw.tween_property(bgm_player, "volume_db", -5.0, _bgm_playlist_fade)

## 曲目播完回调：按设定停顿后自动切到下一首（循环）。
func _on_playlist_track_finished() -> void:
	if not _bgm_playlist_active or _bgm_playlist.is_empty():
		return
	# 切到下一首（循环）
	_bgm_playlist_index = (_bgm_playlist_index + 1) % _bgm_playlist.size()
	# 停顿后播放下一首
	await get_tree().create_timer(_bgm_playlist_pause).timeout
	_play_playlist_current()

# ===== 自适应音频（恐怖游戏专用） =====

var _muffle_tween: Tween = null

## 设置音频低通滤波（muffle）程度
## amount: 0.0 = 清晰，1.0 = 严重沉闷
## 用于：低理智、怪物靠近、Director 高峰期
func set_audio_muffle(amount: float, fade_time: float = 0.5) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx < 0:
		return
	# 确保低通滤波器存在
	if AudioServer.get_bus_effect_count(bus_idx) < 1:
		var lp := AudioEffectLowPassFilter.new()
		lp.resource_name = "HorrorMuffle"
		AudioServer.add_bus_effect(bus_idx, lp)
	var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus_idx, 0)
	var target_hz := lerpf(20000.0, 400.0, clampf(amount, 0.0, 1.0))
	if _muffle_tween and _muffle_tween.is_valid():
		_muffle_tween.kill()
	_muffle_tween = create_tween()
	_muffle_tween.tween_property(filter, "cutoff_hz", target_hz, fade_time)

## 同时设置 BGM bus 的滤波
func set_bgm_muffle(amount: float, fade_time: float = 0.5) -> void:
	var bus_idx := AudioServer.get_bus_index("BGM")
	if bus_idx < 0:
		return
	if AudioServer.get_bus_effect_count(bus_idx) < 1:
		var lp := AudioEffectLowPassFilter.new()
		lp.resource_name = "BGMMuffle"
		AudioServer.add_bus_effect(bus_idx, lp)
	var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus_idx, 0)
	var target_hz := lerpf(20000.0, 600.0, clampf(amount, 0.0, 1.0))
	var tw := create_tween()
	tw.tween_property(filter, "cutoff_hz", target_hz, fade_time)

## 连接到 Director 信号（在关卡 _ready 中调用）
func connect_director() -> void:
	if Director:
		Director.tension_changed.connect(_on_director_tension_changed)
		Director.peak_reached.connect(_on_director_peak)
		Director.relief_started.connect(_on_director_relief)

## Director 张力变化回调：张力超过阈值时逐步加重低通混音。
## [param t] 当前张力值（0.0 ~ 1.0）。
func _on_director_tension_changed(t: float) -> void:
	# 张力 > 0.7 时开始轻微混音
	if t > 0.7:
		set_audio_muffle((t - 0.7) / 0.3 * 0.3, 1.0)  # 最多 30% 混音
	else:
		set_audio_muffle(0.0, 1.0)

## Director 高峰回调：短暂加重低通混音。
func _on_director_peak() -> void:
	# 高峰时短暂加重混音
	set_audio_muffle(0.5, 0.3)

## Director 缓释回调：缓慢恢复清晰音质。
func _on_director_relief() -> void:
	# 释放时缓慢恢复清晰
	set_audio_muffle(0.0, 3.0)
