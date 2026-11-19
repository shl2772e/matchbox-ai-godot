class_name RankBoard
extends RefCounted
## AI 키우기 대회 순위표 그리기 (대회 화면과 대기 화면이 같이 쓴다).
## entries: [{name, score, plan: [아무 데나, 막을 줄 아는, 아주 잘 두는 친구에게 준 칸 수]}] 점수 높은 순.

const PLAN_COLORS := [Kit.MUSTARD, Kit.TEAL, Kit.RED]


## 오늘 올린 기록만 (점수 높은 순 그대로)
static func today(list: Array) -> Array:
	var d := Today.date_key()
	var out := []
	for e in list:
		if e.get("date", "") == d:
			out.append(e)
	return out


static func paint(ci: CanvasItem, r: Rect2, entries: Array, rows: int, title: String, highlight := -1) -> void:
	var R := Kit.R
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.4), r.size), Kit.LINE, R * 0.8)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.8)
	var head := Rect2(r.position, Vector2(r.size.x, R * 2.6))
	var hs := Kit.box(Kit.NAVY, 0)
	hs.corner_radius_top_left = int(R * 0.8)
	hs.corner_radius_top_right = int(R * 0.8)
	ci.draw_style_box(hs, head)
	Kit.text(ci, Kit.F_TITLE, R * 1.4, title, head, Kit.MUSTARD)
	var row_h := (r.size.y - R * 3.4) / rows
	var fs := minf(R * 1.3, row_h * 0.52)
	if entries.is_empty():
		Kit.text(ci, Kit.F_BODY, R * 1.05, "아직 기록이 없어요", Rect2(r.position.x, r.position.y + R * 2.6, r.size.x, r.size.y - R * 2.6), Kit.INK_SOFT)
		return
	for i in mini(rows, entries.size()):
		var e: Dictionary = entries[i]
		var y := r.position.y + R * 3.0 + i * row_h
		var row := Rect2(r.position.x + R * 0.8, y, r.size.x - R * 1.6, row_h - R * 0.2)
		if i == highlight:
			Kit.rrect(ci, row, Kit.PICK, R * 0.4, R * 0.12, Kit.MUSTARD)
		Kit.text(ci, Kit.F_TITLE, fs, "%d등" % (i + 1), Rect2(row.position.x + R * 0.6, y, R * 3.4, row.size.y), Kit.RED_INK if i < 3 else Kit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
		var nm: String = e.name if e.name != "" else "이름 없음"
		Kit.text(ci, Kit.F_BOLD, fs, nm, Rect2(row.position.x + R * 4.0, y, row.size.x * 0.4, row.size.y), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
		var score_w := R * 5.6
		# 계획: 누구와 얼마나 연습했는지 색 막대로 (자리가 좁으면 그리지 않는다)
		var plan: Array = e.get("plan", [])
		var plan_w := R * 9.0
		var total := 0.0
		for v in plan:
			total += float(v)
		if row.size.x > R * 22 and total > 0.0:
			var px := row.end.x - score_w - R * 0.6 - plan_w
			var bh := minf(R * 0.9, row.size.y * 0.5)
			for t in plan.size():
				var pw: float = plan_w * float(plan[t]) / total
				if pw > 0.5:
					ci.draw_rect(Rect2(px, y + (row.size.y - bh) / 2, pw, bh), plan_color(plan.size(), t))
					px += pw
		Kit.text(ci, Kit.F_TITLE, fs, "%d점" % e.score, Rect2(row.end.x - score_w - R * 0.4, y, score_w, row.size.y), Kit.NAVY, HORIZONTAL_ALIGNMENT_RIGHT)


## 연습 친구의 색
static func friend_color(kind: String) -> Color:
	return Kit.bead_color(SelfPlay.FRIEND_COLOR.get(kind, 0), 1)


## 계획의 t번째 칸 색. 예전 기록(세 친구)도 읽는다
static func plan_color(plan_size: int, t: int) -> Color:
	if plan_size == SelfPlay.CONTEST_FRIENDS.size():
		return friend_color(SelfPlay.CONTEST_FRIENDS[t])
	return PLAN_COLORS[t % 3]
