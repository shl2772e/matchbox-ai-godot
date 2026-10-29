class_name ScreenBase
extends Control
## 화면 공통: 화면 전체를 채우고, 크기가 바뀌면 relayout()으로 다시 배치한다.
## later()의 예약은 화면이 사라지면 함께 사라진다.

## 화면 여백 (웹 앱 .screen padding 1.4rem 2.2rem)
var pad := Vector2(Kit.R * 2.2, Kit.R * 1.4)
var _built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	build()
	_built = true
	resized.connect(relayout)
	relayout()
	enter()


func build() -> void:
	pass


## 처음 배치가 끝난 뒤 한 번 (등장 애니메이션, 예약)
func enter() -> void:
	pass


func relayout() -> void:
	pass


func portrait() -> bool:
	return size.y > size.x


func later(sec: float, fn: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_callback(fn)


## 아래에서 살짝 올라오며 나타나기
func rise_in(node: CanvasItem, delay := 0.0, dist := Kit.R * 1.2) -> void:
	node.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(node, "modulate:a", 1.0, 0.35).set_delay(delay)
	if node is Control:
		var c := node as Control
		var to := c.position
		c.position.y += dist
		tw.tween_property(c, "position:y", to.y, 0.45).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 부드럽게 튀며 내려앉기 (0~1)
static func bounce(p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	const N := 7.5625
	const D := 2.75
	if p < 1 / D:
		return N * p * p
	if p < 2 / D:
		p -= 1.5 / D
		return N * p * p + 0.75
	if p < 2.5 / D:
		p -= 2.25 / D
		return N * p * p + 0.9375
	p -= 2.625 / D
	return N * p * p + 0.984375


static func ease_out(p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	return 1.0 - pow(1.0 - p, 3)
