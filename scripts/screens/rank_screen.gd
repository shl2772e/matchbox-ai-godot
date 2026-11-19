class_name RankScreen
extends ScreenBase
## 첫 화면을 그대로 두면 나오는 큰 순위표 (1~10등). SHOW_S 뒤에 저절로 넘어가고, 누르면 첫 화면으로 간다.

signal done
signal tapped

const SHOW_S := 10.0

var ranking: Array

var _board: Drawn
var _tap: Label
var _time := 0.0
var _gone := false


func _init(rank_list: Array) -> void:
	ranking = rank_list


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_board = Drawn.new(_paint)
	add_child(_board)
	_tap = Kit.pill("화면을 누르면 처음으로 가요", "kid", 1.4)
	add_child(_tap)


func relayout() -> void:
	var R := Kit.R
	_tap.size = _tap.get_combined_minimum_size()
	var by := size.y - pad.y - _tap.size.y - R * 0.8
	_tap.position = Vector2((size.x - _tap.size.x) / 2, by)
	var bw := minf(size.x - pad.x * 2, R * 44)
	_board.position = Vector2((size.x - bw) / 2, pad.y + R * 1.2)
	_board.size = Vector2(bw, by - R * 1.4 - _board.position.y)


func enter() -> void:
	rise_in(_board)
	rise_in(_tap, 0.2)


func _process(delta: float) -> void:
	_time += delta
	if _time >= SHOW_S and not _gone:
		_gone = true
		done.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _gone:
		_gone = true
		tapped.emit()
		accept_event()


func _paint(ci: Drawn) -> void:
	RankBoard.paint(ci, Rect2(Vector2.ZERO, ci.size), RankBoard.today(ranking), 10, "오늘의 순위  AI 키우기 대회")
