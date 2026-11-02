class_name Kit
extends RefCounted
## 시안 A "1961 성냥갑 연구실"의 색·글꼴·그림 도구.
## 화면 기준은 1920×1080(세로 화면은 폭 1920에 맞춰 길어진다). R = 웹 앱의 1rem(27px).
## 색은 여기 상수로만 쓴다. ○와 ×는 색뿐 아니라 모양으로도 구분한다.

const R := 27.0

const PAPER := Color("#eadbc0")
const PAPER_DOT := Color(120 / 255.0, 90 / 255.0, 50 / 255.0, 0.1)
const CREAM := Color("#f7eedb")
const INK := Color("#2b2622")
const INK_SOFT := Color("#5a4630")
const LINE := Color("#b99e73")
const KRAFT := Color("#d9c29a")
const KRAFT_DARK := Color("#c6ac80")
const TRAY := Color("#efe2c8")
const PICK := Color("#fbe6cf")
const WIN_CELL := Color("#fbe6b0")
const RED := Color("#c7412f")
const RED_INK := Color("#a8331f")
const RED_DARK := Color("#8a2a1e")
const NAVY := Color("#233049")
const MUSTARD := Color("#e2a72e")
const TEAL := Color("#2f6f65")

const F_TITLE := preload("res://assets/fonts/BlackHanSans.ttf")
const F_LABEL := preload("res://assets/fonts/DoHyeon.ttf")
const F_BODY := preload("res://assets/fonts/GowunBatang-Regular.ttf")
const F_BOLD := preload("res://assets/fonts/GowunBatang-Bold.ttf")

## 칸마다 구슬 색 [밝은, 가운데, 어두운]. 자리로도 구분되므로 색에만 기대지 않는다
const BEAD_COLORS := [
	["#F5D27E", "#E2A72E", "#A8781A"],
	["#8FB8B0", "#3E7F75", "#2A5A53"],
	["#9DB0D6", "#4A63A0", "#2E3F6A"],
	["#E9A29A", "#C7412F", "#8A2A1E"],
	["#C9A6D6", "#7E4E93", "#563366"],
	["#F2B9A0", "#D9764C", "#9A4A28"],
	["#B8D69A", "#6E9A44", "#4A6B2C"],
	["#F0B3C6", "#C9577C", "#8A3352"],
	["#D9C2A0", "#8A6A45", "#5C4529"],
]


static func bead_color(cell: int, shade := 1) -> Color:
	return Color(BEAD_COLORS[cell][shade])


# ---------- 그림 ----------

static func box(color: Color, radius: float, border := 0.0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(radius))
	s.corner_detail = 10
	s.anti_aliasing = true
	if border > 0.0:
		s.set_border_width_all(int(border))
		s.border_color = border_color
	return s


static func rrect(ci: CanvasItem, rect: Rect2, color: Color, radius: float, border := 0.0, border_color := Color.TRANSPARENT) -> void:
	ci.draw_style_box(box(color, radius, border, border_color), rect)


## 구슬 하나. 둥근 빛을 겹쳐 그려 유리구슬처럼 보이게 한다
static func bead(ci: CanvasItem, pos: Vector2, r: float, cell: int, alpha := 1.0) -> void:
	var a := Color(1, 1, 1, alpha)
	ci.draw_circle(pos + Vector2(0, r * 0.18), r * 1.02, Color(INK, 0.16 * alpha), true, -1.0, true)
	ci.draw_circle(pos, r, bead_color(cell, 2) * a, true, -1.0, true)
	ci.draw_circle(pos - Vector2(r, r) * 0.1, r * 0.86, bead_color(cell, 1) * a, true, -1.0, true)
	ci.draw_circle(pos - Vector2(r * 0.3, r * 0.32), r * 0.42, Color(bead_color(cell, 0), 0.85 * alpha), true, -1.0, true)
	ci.draw_circle(pos - Vector2(r * 0.4, r * 0.42), r * 0.16, Color(1, 1, 1, 0.6 * alpha), true, -1.0, true)


## ○ (AI). p는 그려진 정도 0~1. dashed면 점선(AI가 막 고른 칸)
static func mark_o(ci: CanvasItem, c: Vector2, cell_size: float, p := 1.0, dashed := false, alpha := 1.0) -> void:
	var r := cell_size * 0.2365
	var w := cell_size * 0.0946
	var col := Color(RED, alpha)
	if dashed:
		var n := 12
		for i in n:
			var a0 := TAU * i / n - PI / 2
			ci.draw_arc(c, r, a0, a0 + TAU / n * 0.6, 8, col, w, true)
		return
	if p <= 0.0:
		return
	ci.draw_arc(c, r, -PI / 2, -PI / 2 + TAU * p, maxi(4, int(64 * p)), col, w, true)
	ci.draw_circle(c + Vector2(0, -r), w / 2, col, true, -1.0, true)
	ci.draw_circle(c + Vector2.from_angle(-PI / 2 + TAU * p) * r, w / 2, col, true, -1.0, true)


## × (학생). 두 획을 차례로 긋는다
static func mark_x(ci: CanvasItem, c: Vector2, cell_size: float, p := 1.0, alpha := 1.0) -> void:
	var d := cell_size * 0.208
	var w := cell_size * 0.0946
	var col := Color(NAVY, alpha)
	var strokes := [[c + Vector2(-d, -d), c + Vector2(d, d)], [c + Vector2(d, -d), c + Vector2(-d, d)]]
	for s in 2:
		var q := clampf(p * 2.0 - s, 0.0, 1.0)
		if q <= 0.0:
			continue
		var a: Vector2 = strokes[s][0]
		var b: Vector2 = a.lerp(strokes[s][1], q)
		ci.draw_line(a, b, col, w, true)
		ci.draw_circle(a, w / 2, col, true, -1.0, true)
		ci.draw_circle(b, w / 2, col, true, -1.0, true)


## 작은 판 그림 (성냥갑 상표, 배우는 순간). hl 칸은 겨자색
static func mini_board(ci: CanvasItem, rect: Rect2, board: Array, hl := -1) -> void:
	var gap := rect.size.x * 0.06
	rrect(ci, rect, NAVY, rect.size.x * 0.06)
	var cs := (rect.size.x - gap * 4) / 3.0
	for i in 9:
		var cr := Rect2(rect.position + Vector2(gap + (i % 3) * (cs + gap), gap + (i / 3) * (cs + gap)), Vector2(cs, cs))
		ci.draw_rect(cr, MUSTARD if i == hl else CREAM)
		if board[i] == Ttt.AI:
			mark_o(ci, cr.get_center(), cs * 1.25)
		elif board[i] == Ttt.KID:
			mark_x(ci, cr.get_center(), cs * 1.25)


## 성냥갑 한 개 (대기·안내 그림). 웹 앱 SVG(220×150)를 그대로 옮기고, open(0~1)만큼 서랍이 오른쪽으로 나온다.
## bob은 서랍 속 구슬이 살짝 흔들리는 정도
static func matchbox_art(ci: CanvasItem, rect: Rect2, open := 1.0, bob := 0.0) -> void:
	var k := minf(rect.size.x / 220.0, rect.size.y / 150.0)
	var o := rect.position + (rect.size - Vector2(220, 150) * k) / 2
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * k
	var dx := lerpf(-52.0, 0.0, open)
	if open > 0.01:
		rrect(ci, Rect2(P.call(66 + dx, 58), Vector2(146, 70) * k), KRAFT, 6 * k)
		rrect(ci, Rect2(P.call(72 + dx, 64), Vector2(134, 58) * k), KRAFT_DARK, 4 * k)
		var beads := [[98, 86, 3], [122, 96, 0], [146, 84, 2], [170, 98, 1], [188, 82, 4]]
		for i in beads.size():
			var bb: Array = beads[i]
			var wob := sin(bob * TAU + i * 1.3) * 1.2
			bead(ci, P.call(bb[0] + dx, bb[1] + wob), 9 * k, bb[2])
	rrect(ci, Rect2(P.call(8, 40), Vector2(150, 96) * k), NAVY, 8 * k)
	ci.draw_rect(Rect2(P.call(8, 40), Vector2(150, 16) * k), RED)
	ci.draw_dashed_line(P.call(8, 56), P.call(158, 56), CREAM, 3 * k, 10 * k)
	rrect(ci, Rect2(P.call(24, 68), Vector2(52, 52) * k), CREAM, 4 * k)
	for x in [41, 59]:
		ci.draw_line(P.call(x, 70), P.call(x, 118), NAVY, 3 * k)
	for y in [85, 103]:
		ci.draw_line(P.call(26, y), P.call(74, y), NAVY, 3 * k)
	ci.draw_arc(P.call(50, 94), 6 * k, 0, TAU, 24, RED, 3 * k, true)
	rrect(ci, Rect2(P.call(88, 74), Vector2(56, 8) * k), MUSTARD, 4 * k)
	rrect(ci, Rect2(P.call(88, 92), Vector2(44, 6) * k), Color(CREAM, 0.7), 3 * k)
	rrect(ci, Rect2(P.call(88, 106), Vector2(50, 6) * k), Color(CREAM, 0.7), 3 * k)


## 가운데 맞춘 한 줄 글자. pos는 글자 상자의 왼쪽 위
static func text(ci: CanvasItem, font: Font, size: float, s: String, rect: Rect2, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var fs := int(size)
	var asc := font.get_ascent(fs)
	var h := font.get_height(fs)
	var y := rect.position.y + (rect.size.y - h) / 2 + asc
	ci.draw_string(font, Vector2(rect.position.x, y), s, align, rect.size.x, fs, color)


# ---------- 화면 부품 ----------

## 낱말 가운데서 줄이 바뀌지 않게(웹의 word-break: keep-all) 글자 사이에 WORD JOINER를 넣는다
static func keep_all(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s[i]
		out += ch
		if i < s.length() - 1 and ch != " " and s[i + 1] != " " and ch != "\n" and s[i + 1] != "\n":
			out += "⁠"
	return out


static func label(s: String, font: Font, size: float, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = int(size)
	ls.font_color = color
	ls.line_spacing = size * 0.3
	l.label_settings = ls
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = keep_all(s)
	else:
		l.text = s
	return l


static func set_text(l: Label, s: String) -> void:
	l.text = keep_all(s) if l.autowrap_mode != TextServer.AUTOWRAP_OFF else s


## 너비를 정한 글자를 놓고 높이를 돌려준다
## (Label은 줄 나눔을 다음 그리기 때 하므로, 높이는 글꼴로 직접 잰다)
static func place(l: Control, pos: Vector2, width: float) -> float:
	l.position = pos
	var h := l.get_combined_minimum_size().y
	if l is Label and l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		h = wrapped_height(l, width)
	l.size = Vector2(width, h)
	return h


static func wrapped_height(l: Label, width: float) -> float:
	var ls := l.label_settings
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var lines := 0
	for para in l.text.split("\n"):
		var sz := ls.font.get_multiline_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, width, ls.font_size, -1, flags)
		lines += maxi(1, roundi(sz.y / ls.font.get_height(ls.font_size)))
	return lines * ls.font.get_height(ls.font_size) + (lines - 1) * ls.line_spacing + 2.0


## 버튼: primary(빨강) / soft(크림) / ghost / danger(크림 바탕에 빨간 테두리·글자)
static func button(s: String, kind := "primary", big := false) -> Button:
	var b := Button.new()
	b.text = s
	b.focus_mode = Control.FOCUS_NONE
	var fs := R * (1.6 if big else 1.3)
	var bg: Color = RED if kind == "primary" else (CREAM if kind == "soft" or kind == "danger" else Color.TRANSPARENT)
	var fg: Color = CREAM if kind == "primary" else (RED_INK if kind == "danger" else (INK if kind == "soft" else INK_SOFT))
	var shadow: Color = RED_DARK if kind == "primary" else LINE
	var pad := Vector2(2.0 if big else 1.4, 0.8 if big else 0.6) * R
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s2 := box(bg, R * 0.6, R * 0.11 if kind == "danger" else 0.0, RED)
		var down: bool = state == "pressed"
		s2.content_margin_left = pad.x
		s2.content_margin_right = pad.x
		s2.content_margin_top = pad.y + (R * 0.17 if down else 0.0)
		s2.content_margin_bottom = pad.y - (R * 0.17 if down else 0.0)
		if kind != "ghost":
			s2.shadow_color = shadow
			s2.shadow_size = 0
			s2.shadow_offset = Vector2(0, R * (0.08 if down else 0.25))
			s2.expand_margin_top = -R * 0.17 if down else 0.0
		b.add_theme_stylebox_override(state, s2)
	b.add_theme_font_override("font", F_LABEL)
	b.add_theme_font_size_override("font_size", int(fs))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	return b


## 알약 이름표: kid(남색) / draw(크림) / ai(빨강)
static func pill(s: String, kind: String, size := 1.2) -> Label:
	var l := label(s, F_LABEL, R * size, CREAM if kind != "draw" else INK)
	var bg: Color = NAVY if kind == "kid" else (RED if kind == "ai" else CREAM)
	var st := box(bg, R * 2, R * 0.11 if kind == "draw" else 0.0, NAVY)
	st.content_margin_left = R * 0.9 * size / 1.2
	st.content_margin_right = R * 0.9 * size / 1.2
	st.content_margin_top = R * 0.2 * size / 1.2
	st.content_margin_bottom = R * 0.2 * size / 1.2
	l.add_theme_stylebox_override("normal", st)
	return l


## 자물쇠 (선생님 버튼). open이면 고리가 열려 있다. 웹 앱 Art.tsx의 24칸 아이콘을 옮겼다
static func lock(ci: CanvasItem, rect: Rect2, open: bool, color: Color) -> void:
	var k := rect.size.x / 24.0
	var o := rect.position
	var w := 2.0 * k
	rrect(ci, Rect2(o + Vector2(5, 11) * k, Vector2(14, 10) * k), color, 2 * k)
	var c := o + Vector2(12, 7) * k
	ci.draw_arc(c, 4 * k, PI, TAU if not open else TAU * 0.92, 16, color, w, true)
	ci.draw_line(o + Vector2(8, 7) * k, o + Vector2(8, 11) * k, color, w, true)
	if not open:
		ci.draw_line(o + Vector2(16, 7) * k, o + Vector2(16, 11) * k, color, w, true)
