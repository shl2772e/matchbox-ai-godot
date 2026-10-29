extends Node
## 소리 파일 없이 짧고 부드러운 소리를 만든다 (웹 앱 sound.ts와 같은 음).
## 뽑기·당첨 같은 소리는 쓰지 않는다. 짧은 "톡" 한 번이면 끝이다.

const RATE := 22050

var enabled := true
var _cache := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## 학생이 둠
func tap() -> void:
	_tone(520, 0.0, 0.07, 0.08, true)


## 성냥갑 열림
func open() -> void:
	_tone(300, 0.0, 0.1, 0.05, true)


## AI가 둠 (구슬 톡)
func bead() -> void:
	_tone(780, 0.0, 0.09, 0.07, false)


## 구슬이 늘거나 줆
func learn() -> void:
	_tone(660, 0.0, 0.06, 0.05, true)


## 판 끝
func done() -> void:
	_tone(523, 0.0, 0.16, 0.07, true)
	_tone(659, 0.12, 0.22, 0.07, true)


func _tone(freq: float, start: float, duration: float, gain: float, triangle: bool) -> void:
	if not enabled:
		return
	var key := "%d-%f-%f-%s" % [freq, duration, gain, triangle]
	if not _cache.has(key):
		_cache[key] = _make(freq, duration, gain, triangle)
	if start > 0.0:
		get_tree().create_timer(start).timeout.connect(_play.bind(_cache[key]))
	else:
		_play(_cache[key])


func _play(stream: AudioStreamWAV) -> void:
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return


func _make(freq: float, duration: float, gain: float, triangle: bool) -> AudioStreamWAV:
	var n := int((duration + 0.05) * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var phase := fmod(t * freq, 1.0)
		var w := (4.0 * absf(phase - 0.5) - 1.0) if triangle else sin(TAU * phase)
		# 0.02초에 걸쳐 커졌다가 끝까지 부드럽게 줄어든다
		var env := minf(t / 0.02, 1.0) * pow(0.0001 / gain, clampf((t - 0.02) / maxf(duration - 0.02, 0.001), 0.0, 1.0))
		data.encode_s16(i * 2, int(clampf(w * gain * env * 3.0, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s
