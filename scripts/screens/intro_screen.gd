class_name IntroScreen
extends ScreenBase
## 안내 3장. 장이 바뀔 때마다 그림이 움직인다:
## 1장 서랍이 열림, 2장 칸마다 구슬이 떨어져 담김, 3장 상과 벌 표가 하나씩 놓임.

signal done

const PAGES := [
	["1961년, 성냥갑으로 만든 AI", "컴퓨터가 아주 귀하던 시절, 영국의 과학자 도널드 미치는 성냥갑 304개와 색 구슬로 틱택토를 배우는 기계를 만들었어요."],
	["판 모양마다 성냥갑이 하나", "상자 안에는 둘 수 있는 칸마다 구슬이 들어 있어요. AI는 구슬을 하나 꺼내서 그 칸에 둬요. 구슬이 많은 칸일수록 자주 나와요."],
	["이기면 늘고, 지면 줄어요", "판이 끝나면 AI가 고른 칸에 구슬을 고쳐 넣어요. 이기면 3개 더, 비기면 1개 더, 지면 1개를 빼요. 이렇게 AI가 배워요."],
]
const TRAY := [4, 1, 2, 0, 3, 1, 2, 4, 1]

var _page := 0
var _card: Drawn
var _content: Control
var _art: Drawn
var _count: Label
var _title: Label
var _text: Label
var _skip: Button
var _next: Button
var _time := 0.0


func build() -> void:
	_card = Drawn.new(_paint_card)
	add_child(_card)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_content)
	_art = Drawn.new(_paint_art)
	_content.add_child(_art)
	_count = Kit.label("", Kit.F_LABEL, Kit.R * 1.2, Kit.RED_INK)
	_title = Kit.label("", Kit.F_TITLE, Kit.R * 2.5, Kit.NAVY, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text = Kit.label("", Kit.F_BODY, Kit.R * 1.45, Kit.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text.label_settings.line_spacing = Kit.R * 0.6
	for l in [_count, _title, _text]:
		_content.add_child(l)
	_skip = Kit.button("건너뛰기", "soft")
	_next = Kit.button("다음", "primary", true)
	_skip.pressed.connect(func() -> void: done.emit())
	_next.pressed.connect(_on_next)
	add_child(_skip)
	add_child(_next)
	_show_page()


func _on_next() -> void:
	if _page == PAGES.size() - 1:
		done.emit()
		return
	_page += 1
	_show_page()
	relayout()
	# 새 장은 오른쪽에서 밀려 들어온다
	_content.modulate.a = 0.0
	_content.position.x = Kit.R * 3
	var tw := create_tween().set_parallel()
	tw.tween_property(_content, "modulate:a", 1.0, 0.3)
	tw.tween_property(_content, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_page() -> void:
	_time = 0.0
	_count.text = "%d / %d" % [_page + 1, PAGES.size()]
	Kit.set_text(_title, PAGES[_page][0])
	Kit.set_text(_text, PAGES[_page][1])
	_next.text = "한 판 두기" if _page == PAGES.size() - 1 else "다음"


func relayout() -> void:
	var R := Kit.R
	var vertical := portrait()
	var cw := minf(size.x - pad.x * 2, R * 58)
	var art_size := Vector2(R * 19, R * 15)
	var inset := R * 2.4
	var text_w := cw - inset * 2 if vertical else cw - inset * 2 - art_size.x - R * 2
	var tx := inset if vertical else inset + art_size.x + R * 2
	# 글 묶음 높이를 먼저 재고
	var th := Kit.place(_count, Vector2(tx, 0), text_w) + R * 0.5
	var title_y := th
	th += Kit.place(_title, Vector2(tx, th), text_w) + R * 0.9
	var text_y := th
	th += Kit.place(_text, Vector2(tx, th), text_w)
	var ch: float
	var ty: float
	if vertical:
		_art.position = Vector2((cw - art_size.x) / 2, R * 2)
		ty = R * 2 + art_size.y + R * 1.5
		ch = ty + th + inset
	else:
		ch = maxf(th, art_size.y) + inset * 2
		_art.position = Vector2(inset, (ch - art_size.y) / 2)
		ty = (ch - th) / 2
	_art.size = art_size
	_count.position.y = ty
	_title.position.y = ty + title_y
	_text.position.y = ty + text_y
	var bh := _next.get_combined_minimum_size().y
	var top := (size.y - ch - R * 2 - bh) / 2
	_card.position = Vector2((size.x - cw) / 2, top)
	_card.size = Vector2(cw, ch)
	_content.size = _card.size
	_next.size = _next.get_combined_minimum_size()
	_skip.size = _skip.get_combined_minimum_size()
	var by := top + ch + R * 2
	_next.position = Vector2(_card.position.x + cw - _next.size.x, by)
	_skip.position = Vector2(_next.position.x - R * 1.2 - _skip.size.x, by + (bh - _skip.size.y) / 2)


func enter() -> void:
	rise_in(_card)
	rise_in(_skip, 0.2)
	rise_in(_next, 0.2)


func _process(delta: float) -> void:
	_time += delta
	_art.t = _time


func _paint_card(ci: Drawn) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, Rect2(Vector2(0, Kit.R * 0.4), r.size), Kit.LINE, Kit.R * 0.9)
	Kit.rrect(ci, r, Kit.CREAM, Kit.R * 0.9)


func _paint_art(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	var t := ci.t
	match _page:
		0:
			Kit.matchbox_art(ci, r, ease_out((t - 0.3) / 0.9), t / 1.6)
		1:
			# 3×3 서랍에 칸마다 구슬이 하나씩 떨어져 담긴다
			var tray := Rect2(r.position + Vector2(R * 1.0, R * 0.5), Vector2(r.size.y - R * 1.0, r.size.y - R * 1.0))
			tray.position.x = (r.size.x - tray.size.x) / 2
			Kit.rrect(ci, Rect2(tray.position + Vector2(0, R * 0.3), tray.size), Kit.KRAFT_DARK, R * 0.7)
			Kit.rrect(ci, tray, Kit.KRAFT, R * 0.7)
			var gap := R * 0.35
			var cs := (tray.size.x - gap * 4) / 3
			var br := cs * 0.11
			for i in 9:
				var sr := Rect2(tray.position + Vector2(gap + (i % 3) * (cs + gap), gap + (i / 3) * (cs + gap)), Vector2(cs, cs))
				Kit.rrect(ci, sr, Kit.TRAY, R * 0.35)
				var n: int = TRAY[i]
				for k in n:
					var start := 0.25 + i * 0.09 + k * 0.14
					var p := (t - start) / 0.45
					if p <= 0.0:
						continue
					var home := sr.get_center() + Vector2(((k % 2) - 0.5) * br * 2.3, ((k / 2) - (ceili(n / 2.0) - 1) / 2.0) * br * 2.3)
					if n == 1:
						home = sr.get_center()
					var y := lerpf(home.y - cs * 0.9, home.y, bounce(p))
					Kit.bead(ci, Vector2(home.x, y), br, i, clampf(p * 3.0, 0.0, 1.0))
		2:
			# 상과 벌 표 세 장이 차례로 놓인다
			var rows := [["AI 이김", "+3", Kit.RED, Kit.CREAM], ["비김", "+1", Kit.CREAM, Kit.INK], ["AI 짐", "−1", Kit.NAVY, Kit.CREAM]]
			var h := R * 3.6
			var gap := R * 0.9
			var top := (r.size.y - h * 3 - gap * 2) / 2
			for i in 3:
				var p := ease_out((t - 0.2 - i * 0.3) / 0.45)
				if p <= 0.0:
					continue
				var row: Array = rows[i]
				var rr := Rect2(Vector2(R * 1.5 + (1.0 - p) * R * 3, top + i * (h + gap)), Vector2(r.size.x - R * 3, h))
				var fg: Color = row[3]
				Kit.rrect(ci, Rect2(rr.position + Vector2(0, R * 0.25), rr.size), Color(Kit.LINE, p), R * 0.6)
				Kit.rrect(ci, rr, Color(row[2], p), R * 0.6, R * 0.11 if i == 1 else 0.0, Color(Kit.NAVY, p))
				Kit.text(ci, Kit.F_LABEL, R * 1.6, row[0], Rect2(rr.position + Vector2(R * 1.2, 0), Vector2(rr.size.x, h)), Color(fg, p), HORIZONTAL_ALIGNMENT_LEFT)
				Kit.text(ci, Kit.F_TITLE, R * 2.4, row[1], Rect2(rr.position, rr.size - Vector2(R * 1.2, 0)), Color(fg, p), HORIZONTAL_ALIGNMENT_RIGHT)
