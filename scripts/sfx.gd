extends Node
## 소리 파일 없이 짧고 부드러운 소리를 만든다 (웹 앱 sound.ts와 같은 음).
## 뽑기·당첨 같은 소리는 쓰지 않는다. 짧은 "톡" 한 번이면 끝이다.

const RATE := 22050

var enabled := true
var _cache := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in 8:
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


# ---------- 새 흐름에서 쓰는 소리 ----------

## 유리구슬이 부딪히는 소리 (높은 음 둘이 짧게 울린다). 상과 벌을 줄 때
func clink(delay := 0.0) -> void:
	_tone(2093, delay, 0.12, 0.035, false)
	_tone(3136, delay, 0.08, 0.02, false)


## 성냥갑 서랍이 미끄러지는 소리 (짧은 바람 소리)
func slide() -> void:
	_noise(0.0, 0.16, 0.05)


## 빨리 감기 중 한 판이 끝날 때 (아주 작게)
func tick() -> void:
	_tone(880, 0.0, 0.03, 0.02, true)


## 졸업장 (차분한 세 음)
func grad() -> void:
	_tone(523, 0.0, 0.2, 0.06, true)
	_tone(659, 0.14, 0.2, 0.06, true)
	_tone(784, 0.28, 0.3, 0.06, true)


func _noise(start: float, duration: float, gain: float) -> void:
	if not enabled:
		return
	var key := "noise-%f-%f" % [duration, gain]
	if not _cache.has(key):
		_cache[key] = _make_noise(duration, gain)
	if start > 0.0:
		get_tree().create_timer(start).timeout.connect(_play.bind(_cache[key]))
	else:
		_play(_cache[key])


## 부드러운 잡음: 무작위 값을 앞 값과 섞어(저역 통과) 종이 스치는 소리처럼 만든다
func _make_noise(duration: float, gain: float) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := SeededRng.new(1961)
	var prev := 0.0
	for i in n:
		var p := float(i) / n
		prev = prev * 0.82 + (rng.next() * 2.0 - 1.0) * 0.18
		var env := sin(p * PI)
		data.encode_s16(i * 2, int(clampf(prev * gain * env * 6.0, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s
