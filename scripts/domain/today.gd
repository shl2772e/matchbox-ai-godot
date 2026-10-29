class_name Today
extends RefCounted
## 오늘의 공동 성적. 날짜가 바뀌면 새로 시작하고, AI 구슬은 그대로 둔다.
## {"date": "2026-10-29", "games", "kid", "draw", "ai", "recent": [승부...]}

const RECENT_MAX := 2000


static func date_key(d: Dictionary = Time.get_date_dict_from_system()) -> String:
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func fresh(date := date_key()) -> Dictionary:
	return {"date": date, "games": 0, "kid": 0, "draw": 0, "ai": 0, "recent": []}


static func roll(t: Dictionary, date := date_key()) -> Dictionary:
	return t if t.get("date", "") == date else fresh(date)


static func add_result(t: Dictionary, o: String, date := date_key()) -> Dictionary:
	var cur := roll(t, date).duplicate(true)
	cur.games += 1
	cur[o] += 1
	cur.recent.append(o)
	if cur.recent.size() > RECENT_MAX:
		cur.recent = cur.recent.slice(-RECENT_MAX)
	return cur


static func from_json(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY or not data.has("date"):
		return fresh()
	var t := fresh(str(data.date))
	for k in ["games", "kid", "draw", "ai"]:
		t[k] = int(data.get(k, 0))
	t.recent = Array(data.get("recent", []))
	return t
