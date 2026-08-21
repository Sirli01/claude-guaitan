extends Node
class_name ProceduralSFX
## 程序化音效生成器 - 生成恐怖游戏常用音效
## 用法：var stream = ProceduralSFX.high_heel_step()
##       AudioManager.play_sfx(stream)

const HIGH_HEEL_STEP_PATH := "res://assets/audio/sfx/high_heel.mp3"
const SHADOW_MOVE_PATH := "res://assets/audio/sfx/shadow_move.mp3"

static func _load_optional_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null

## 高跟鞋脚步声（尖锐的咔哒声）
static func high_heel_step() -> AudioStream:
	var stream := _load_optional_stream(HIGH_HEEL_STEP_PATH)
	if stream:
		return stream

	var rate := 22050
	var dur := 0.12
	var samples := int(rate * dur)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in samples:
		var t := float(i) / rate
		var env := exp(-t * 40.0)  # 极快衰减
		# 高频敲击 + 金属回响
		var sample := sin(t * TAU * 800.0) * env * 0.6
		sample += sin(t * TAU * 2200.0) * env * 0.3
		sample += sin(t * TAU * 4500.0) * env * 0.15
		var int_val := clampi(int(sample * 28000), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	var generated_stream := AudioStreamWAV.new()
	generated_stream.format = AudioStreamWAV.FORMAT_16_BITS
	generated_stream.mix_rate = rate
	generated_stream.data = data
	return generated_stream

## 低沉地鸣声（深渊巨口出现前的预警）
static func ground_rumble() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.8
	var samples := int(rate * dur)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in samples:
		var t := float(i) / rate
		var env := sin(t / dur * PI)  # 中间最大
		var sample := sin(t * TAU * 30.0) * env * 0.5
		sample += sin(t * TAU * 55.0) * env * 0.3
		sample += randf_range(-0.1, 0.1) * env  # 噪声
		var int_val := clampi(int(sample * 24000), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

## 怪物缓慢脚步声（沉重、湿润的拖拽声）
static func monster_step() -> AudioStream:
	var stream := _load_optional_stream(SHADOW_MOVE_PATH)
	if stream:
		return stream

	var rate := 22050
	var dur := 0.25
	var samples := int(rate * dur)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in samples:
		var t := float(i) / rate
		var env := exp(-t * 12.0)
		# 低频 + 噪声 = 沉重拖步
		var sample := sin(t * TAU * 80.0) * env * 0.4
		sample += sin(t * TAU * 140.0) * env * 0.2
		sample += randf_range(-0.15, 0.15) * env  # 粗糙摩擦感
		var int_val := clampi(int(sample * 22000), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	var generated_stream := AudioStreamWAV.new()
	generated_stream.format = AudioStreamWAV.FORMAT_16_BITS
	generated_stream.mix_rate = rate
	generated_stream.data = data
	return generated_stream

## 金属碰撞声（电梯到达）
static func metal_clang() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.4
	var samples := int(rate * dur)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in samples:
		var t := float(i) / rate
		var env := exp(-t * 8.0)
		var sample := sin(t * TAU * 300.0) * env * 0.3
		sample += sin(t * TAU * 750.0) * env * 0.2
		sample += sin(t * TAU * 1800.0) * env * 0.1
		var int_val := clampi(int(sample * 26000), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
