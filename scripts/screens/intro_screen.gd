class_name IntroScreen
extends ScreenBase
## 안내 4장 (대본 A "오늘 내가 AI 선생님").
## 1장 신문: 1961년 컴퓨터 없이 만든 배우는 기계 (사진). 2장 앨범: 미치 박사와 220판의 기록 (사진·그래프).
## 3장 구슬 수가 곧 마음 (구슬이 떨어져 담김). 4장 상과 벌 (표가 하나씩 놓임).
## 사진은 CC BY-SA 라이선스라 화면에 작게 출처를 적는다 (docs/CREDITS.md).

signal done

const PAGES := [
	{
		"kind": "news",
		"title": "1961년, 컴퓨터 없이 배우는 기계",
		"text": "영국의 과학자 도널드 미치는 성냥갑 304개와 색 구슬로 틱택토를 두는 기계를 만들었어요. 이기는 법은 아무도 알려 주지 않았는데, 수백 판을 두자 점점 지지 않게 되었어요.",
		"caption": "성냥갑 304개로 만든 메나스(MENACE). 2018년에 똑같이 다시 만든 것.  사진 Matthew Scroggs · CC BY-SA 4.0",
	},
	{
		"kind": "album",
		"title": "박사와 기계의 기록",
		"text": "도널드 미치 박사(전쟁 때는 앨런 튜링과 함께 암호를 풀었어요)와, 박사가 메나스와 약 220판을 둔 기록이에요. 처음엔 기계가 지기만 하다가, 스무 판쯤 뒤부터 비기기 시작했어요.",
		"caption": "사진 Petermowforth · CC BY-SA 3.0   그래프 Matthew Scroggs · CC BY-SA 4.0",
	},
	{
		"kind": "tray",
		"title": "구슬 수가 곧 마음",
		"text": "판 모양마다 성냥갑이 하나씩 있어요. 상자 속에는 둘 수 있는 칸마다 구슬이 들어 있고, AI는 구슬 하나를 꺼내 그 칸에 둬요. 구슬이 많은 칸일수록 자주 나와요. 그러니까 구슬 수는 \"AI가 그 칸을 얼마나 좋아하는지\"예요.",
	},
	{
		"kind": "rewards",
		"title": "가르치는 방법은 상과 벌",
		"text": "판이 끝나면 AI가 쓴 상자에 구슬을 고쳐 넣어요. AI가 이기면 그 칸에 3개 더(상), 비기면 1개 더, 지면 1개를 빼요(벌). 이게 전부예요. 누구도 이기는 법을 알려 주지 않지만, 수백 판을 두면 AI는 지는 수를 점점 안 두게 돼요. 오늘 내가 두는 판도 AI의 수업이에요.",
	},
]
const TRAY := [4, 1, 2, 0, 3, 1, 2, 4, 1]

const PHOTO_MENACE := preload("res://assets/photos/menace-2018.jpg")
const PHOTO_MICHIE := preload("res://assets/photos/michie-1986.jpg")
const PHOTO_GRAPH := preload("res://assets/photos/michie-graph.png")
const PHOTO_PORTRAIT := preload("res://assets/photos/michie-2003.jpg")
const PORTRAIT_CAPTION := "도널드 미치 박사 (1923~2007)\n사진 Donald Michie · CC BY 4.0"

var _page := 0
## 마지막 장의 단추 글자 (졸업장의 "더 알아보기"로 왔을 때는 "처음으로")
var last_text := "한 판 두기"
## 대기 화면의 소개 돌려 보기: 단추 없이 한 장씩 저절로 넘어가고, 화면을 누르면 start (체험 시작)
signal start
const ATTRACT_S := 9.0
var attract := false
var _tap: Label
var _started := false
var _card: Drawn
var _content: Control
var _art: Drawn
var _count: Label
var _title: Label
var _text: Label
var _caption: Label
var _cap2: Label  ## 신문의 인물 사진 설명
var _skip: Button
var _next: Button
var _time := 0.0
## 사진 자리 (카드 좌표). 그리기와 배치가 같이 쓴다
var _photo_a := Rect2()
var _photo_b := Rect2()
var _photo_c := Rect2()


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
	_caption = Kit.label("", Kit.F_BODY, Kit.R * 1.0, Kit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true)
	_caption.label_settings.line_spacing = Kit.R * 0.3
	_cap2 = Kit.label(PORTRAIT_CAPTION, Kit.F_BODY, Kit.R * 1.0, Kit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true)
	_cap2.label_settings.line_spacing = Kit.R * 0.3
	for l in [_count, _title, _text, _caption, _cap2]:
		_content.add_child(l)
	_skip = Kit.button("건너뛰기", "soft")
	_next = Kit.button("다음", "primary", true)
	_next.custom_minimum_size.x = Kit.R * 10.5  # "한 판 두기"도 같은 너비
	_skip.pressed.connect(func() -> void: done.emit())
	_next.pressed.connect(_on_next)
	add_child(_skip)
	add_child(_next)
	if attract:
		_skip.visible = false
		_next.visible = false
		mouse_filter = Control.MOUSE_FILTER_STOP
		_tap = Kit.pill("화면을 누르면 시작해요", "kid", 1.5)
		add_child(_tap)
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
	_card.queue_redraw()


func _kind() -> String:
	return PAGES[_page].kind


func _show_page() -> void:
	_time = 0.0
	var p: Dictionary = PAGES[_page]
	_count.text = "%d / %d" % [_page + 1, PAGES.size()]
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	Kit.set_text(_title, p.title)
	Kit.set_text(_text, p.text)
	Kit.set_text(_caption, p.get("caption", ""))
	_caption.visible = p.has("caption")
	_cap2.visible = _kind() == "news"
	_next.text = last_text if _page == PAGES.size() - 1 else "다음"
	# 신문·앨범은 사진이 주인공이라 본문이 조금 작다. 앨범의 caption은 출처 한 줄
	var news := _kind() == "news"
	var album := _kind() == "album"
	_title.label_settings.font_size = int(Kit.R * (2.3 if news else 2.5))
	_text.label_settings.font_size = int(Kit.R * (1.25 if album or news else 1.45))
	_text.label_settings.line_spacing = Kit.R * (0.5 if album or news else 0.6)
	_caption.label_settings.font_size = int(Kit.R * (0.9 if album else 1.0))


func relayout() -> void:
	match _kind():
		"news":
			_layout_news()
		"album":
			_layout_album()
		_:
			_layout_art()
	_place_buttons()


## 사진 폭으로 높이를 정한다
static func _fit(tex: Texture2D, w: float) -> Vector2:
	return Vector2(w, w * tex.get_height() / tex.get_width())


## 글을 사진 오른쪽에, 세로 가운데 맞춰 놓는다
static func _place_beside(l: Label, photo: Rect2, w: float) -> void:
	var h := Kit.place(l, Vector2(photo.end.x + Kit.R * 1.0, photo.position.y), w)
	l.position.y = photo.position.y + (photo.size.y - h) / 2


func _layout_news() -> void:
	var R := Kit.R
	var vertical := portrait()
	var cw := minf(size.x - pad.x * 2, R * 60)
	var inset := R * 2.0
	var mast_h := R * 3.4
	var inner := cw - inset * 2
	var y := mast_h + R * 0.9
	y += Kit.place(_count, Vector2(inset, y), inner) + R * 0.3
	y += Kit.place(_title, Vector2(inset, y), inner) + R * 0.9
	var photo_w := inner if vertical else R * 27
	_photo_a = Rect2(Vector2(inset, y), _fit(PHOTO_MENACE, photo_w))
	var cap_h := Kit.place(_caption, Vector2(inset, _photo_a.end.y + R * 0.5), photo_w)
	var left_bottom := _photo_a.end.y + R * 0.5 + cap_h
	# 본문 아래에 박사 초상(정사각형)과 그 설명을 한 줄로
	var ps := R * 7.0
	var ch: float
	if vertical:
		y = left_bottom + R * 1.2
		y += Kit.place(_text, Vector2(inset, y), inner) + R * 1.2
		_photo_c = Rect2(Vector2(inset, y), Vector2(ps, ps))
		_place_beside(_cap2, _photo_c, inner - ps - R * 1.0)
		ch = _photo_c.end.y + inset
	else:
		var tx := inset + photo_w + R * 1.6
		var tw := cw - tx - inset
		var th := Kit.place(_text, Vector2(tx, y), tw)
		_photo_c = Rect2(Vector2(tx, y + th + R * 1.2), Vector2(ps, ps))
		_place_beside(_cap2, _photo_c, tw - ps - R * 1.0)
		ch = maxf(left_bottom, _photo_c.end.y) + inset
	_art.visible = false
	_card.size = Vector2(cw, ch)
	_card.position.x = (size.x - cw) / 2


func _layout_album() -> void:
	var R := Kit.R
	var vertical := portrait()
	var cw := minf(size.x - pad.x * 2, R * 56)
	var inset := R * 2.0
	# 가로 화면: 사진 두 장을 한 뼘 간격으로 붙이고, 종이 폭도 거기에 맞춘다 (가운데가 비지 않게)
	var h := R * 13.0
	var wa := h * PHOTO_MICHIE.get_width() / PHOTO_MICHIE.get_height()
	var wb := h * PHOTO_GRAPH.get_width() / PHOTO_GRAPH.get_height()
	var gap := R * 1.8
	if not vertical:
		cw = minf(cw, wa + gap + wb + inset * 2)
	var inner := cw - inset * 2
	var y := inset
	if vertical:
		y += Kit.place(_count, Vector2(inset, y), inner) + R * 0.3
	else:
		# 가로 화면은 높이가 빠듯해서 쪽수를 제목 줄 오른쪽에 둔다
		Kit.place(_count, Vector2(inset, y + R * 0.9), inner)
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	y += Kit.place(_title, Vector2(inset, y), inner) + R * 1.0
	# 사진 두 장 아래에 설명 한 덩어리, 맨 아래 출처 한 줄
	if vertical:
		_photo_a = Rect2(Vector2(inset + R, y), _fit(PHOTO_MICHIE, inner - R * 2))
		var gw := inner * 0.72
		_photo_b = Rect2(Vector2(inset + (inner - gw) / 2, _photo_a.end.y + R * 1.4), _fit(PHOTO_GRAPH, gw))
		y = _photo_b.end.y + R * 1.0
	else:
		var x0 := inset + (inner - wa - gap - wb) / 2
		_photo_a = Rect2(Vector2(x0, y), Vector2(wa, h))
		_photo_b = Rect2(Vector2(x0 + wa + gap, y), Vector2(wb, h))
		y += h + R * 1.0
	y += Kit.place(_text, Vector2(inset, y), inner) + R * 0.6
	var ch := y + Kit.place(_caption, Vector2(inset, y), inner) + inset
	_art.visible = false
	_card.size = Vector2(cw, ch)
	_card.position.x = (size.x - cw) / 2


func _layout_art() -> void:
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
	_art.visible = true
	_count.position.y = ty
	_title.position.y = ty + title_y
	_text.position.y = ty + text_y
	_card.size = Vector2(cw, ch)
	_card.position.x = (size.x - cw) / 2


## 버튼은 화면 오른쪽 아래 한자리에 고정한다 (터치패널에서 손이 헤매지 않게). 카드는 그 위 공간의 가운데
func _place_buttons() -> void:
	var R := Kit.R
	_next.size = _next.get_combined_minimum_size()
	_skip.size = _skip.get_combined_minimum_size()
	var by := size.y - pad.y - _next.size.y
	_next.position = Vector2(size.x - pad.x - _next.size.x, by)
	_skip.position = Vector2(_next.position.x - R * 1.2 - _skip.size.x, by + (_next.size.y - _skip.size.y) / 2)
	if _tap:
		_tap.size = _tap.get_combined_minimum_size()
		_tap.position = Vector2((size.x - _tap.size.x) / 2, by + (_next.size.y - _tap.size.y) / 2)
	var ch := _card.size.y
	_card.position.y = maxf(pad.y, pad.y + (by - R - pad.y - ch) / 2)
	_content.size = _card.size


func enter() -> void:
	rise_in(_card)
	rise_in(_skip, 0.2)
	rise_in(_next, 0.2)


func _process(delta: float) -> void:
	_time += delta
	_art.t = _time
	if attract and _time >= ATTRACT_S:
		_on_next()
		return
	if _kind() == "news" or _kind() == "album":
		_card.t = _time


func _paint_card(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	match _kind():
		"news":
			_paint_news(ci, r)
		"album":
			_paint_album(ci, r)
		_:
			Kit.rrect(ci, Rect2(Vector2(0, R * 0.4), r.size), Kit.LINE, R * 0.9)
			Kit.rrect(ci, r, Kit.CREAM, R * 0.9)


## 신문: 누런 종이, 제호 띠, 겹줄, 사진
func _paint_news(ci: Drawn, r: Rect2) -> void:
	var R := Kit.R
	var inset := R * 2.0
	ci.draw_rect(Rect2(r.position + Vector2(R * 0.3, R * 0.5), r.size), Color(Kit.INK, 0.12))
	ci.draw_rect(r, Kit.CREAM)
	ci.draw_rect(r, Kit.INK, false, 2.0)
	# 제호는 분위기만: 신문 이름과 날짜, 겹줄
	var mast := Rect2(inset, R * 0.8, r.size.x - inset * 2, R * 2.0)
	Kit.text(ci, Kit.F_TITLE, R * 1.8, "성냥갑 연구실 신문", mast, Kit.INK)
	Kit.text(ci, Kit.F_LABEL, R * 0.95, "1961년 · 영국", mast, Kit.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	var ly := R * 3.0
	ci.draw_line(Vector2(inset, ly), Vector2(r.size.x - inset, ly), Kit.INK, 2.5)
	ci.draw_line(Vector2(inset, ly + R * 0.25), Vector2(r.size.x - inset, ly + R * 0.25), Kit.INK, 1.0)
	_photo(ci, PHOTO_MENACE, _photo_a, Kit.INK, R * 0.08)
	_photo(ci, PHOTO_PORTRAIT, _photo_c, Kit.INK, R * 0.08)


## 앨범: 갈색 종이 위에 사진 두 장, 모서리에 테이프
func _paint_album(ci: Drawn, r: Rect2) -> void:
	var R := Kit.R
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.4), r.size), Kit.KRAFT_DARK, R * 0.9)
	Kit.rrect(ci, r, Kit.KRAFT, R * 0.9)
	# 종이 결
	var y := R * 1.2
	while y < r.size.y:
		ci.draw_line(Vector2(R * 0.8, y), Vector2(r.size.x - R * 0.8, y), Color(Kit.KRAFT_DARK, 0.35), 1.0)
		y += R * 1.2
	_photo(ci, PHOTO_MICHIE, _photo_a, Kit.CREAM, R * 0.35, true)
	_photo(ci, PHOTO_GRAPH, _photo_b, Kit.CREAM, R * 0.35, true)


## 사진 한 장: 테두리(인화지)와 그림자, tape면 모서리 테이프
func _photo(ci: CanvasItem, tex: Texture2D, rect: Rect2, frame: Color, border: float, tape := false) -> void:
	var R := Kit.R
	var outer := rect.grow(border)
	ci.draw_rect(Rect2(outer.position + Vector2(R * 0.15, R * 0.3), outer.size), Color(Kit.INK, 0.18))
	ci.draw_rect(outer, frame)
	ci.draw_texture_rect(tex, rect, false)
	if tape:
		for c in [outer.position, Vector2(outer.end.x, outer.position.y), Vector2(outer.position.x, outer.end.y), outer.end]:
			var ang := PI / 4 if (c.x == outer.position.x) == (c.y == outer.position.y) else -PI / 4
			var hw := R * 1.3
			var hh := R * 0.45
			var pts := PackedVector2Array()
			for p in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
				pts.append(c + p.rotated(ang))
			ci.draw_colored_polygon(pts, Color(Kit.MUSTARD, 0.55))


func _paint_art(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	var t := ci.t
	match _kind():
		"tray":
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
		"rewards":
			# 상과 벌 표 세 장이 차례로 놓인다
			var rows := [["AI 이김 · 상", "+3", Kit.RED, Kit.CREAM], ["비김 · 작은 상", "+1", Kit.CREAM, Kit.INK], ["AI 짐 · 벌", "−1", Kit.NAVY, Kit.CREAM]]
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
				Kit.text(ci, Kit.F_LABEL, R * 1.5, row[0], Rect2(rr.position + Vector2(R * 1.2, 0), Vector2(rr.size.x, h)), Color(fg, p), HORIZONTAL_ALIGNMENT_LEFT)
				Kit.text(ci, Kit.F_TITLE, R * 2.4, row[1], Rect2(rr.position, rr.size - Vector2(R * 1.2, 0)), Color(fg, p), HORIZONTAL_ALIGNMENT_RIGHT)


func _gui_input(event: InputEvent) -> void:
	if attract and event is InputEventMouseButton and event.pressed and not _started:
		_started = true
		start.emit()
		accept_event()
