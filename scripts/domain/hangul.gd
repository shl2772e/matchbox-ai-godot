class_name Hangul
extends RefCounted
## 낱자(ㄱ, ㅏ ...)를 차례로 받아 글자로 모은다 (화면 자판으로 이름을 적을 때 쓴다).
## 누른 낱자를 그대로 모아 두고, 매번 처음부터 다시 모아 쓴다 (지우기는 낱자 하나를 빼면 된다).

const CHO := "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"
const JUNG := "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ"
const JONG := ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
## 겹모음, 겹받침
const DV := {"ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ", "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ", "ㅡㅣ": "ㅢ"}
const DJ := {"ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ"}


static func is_vowel(j: String) -> bool:
	return JUNG.contains(j)


static func _syllable(cho: String, jung: String, jong: String) -> String:
	if cho != "" and jung != "":
		return String.chr(0xAC00 + (CHO.find(cho) * 21 + JUNG.find(jung)) * 28 + JONG.find(jong))
	return cho + jung + jong


## 낱자 배열을 글자로 모은다
static func compose(jamos: Array) -> String:
	var out := ""
	var cho := ""
	var jung := ""
	var jong := ""
	for j: String in jamos:
		if not is_vowel(j) and not CHO.contains(j):
			# 낱자가 아닌 글자(숫자 등)는 그대로
			out += _syllable(cho, jung, jong) + j
			cho = ""
			jung = ""
			jong = ""
		elif is_vowel(j):
			if jung == "":
				jung = j
			elif jong == "":
				if DV.has(jung + j):
					jung = DV[jung + j]
				else:
					out += _syllable(cho, jung, jong)
					cho = ""
					jung = j
			else:
				# 받침이 다음 글자의 첫소리로 넘어간다 (겹받침이면 뒤쪽 것만)
				var move := jong
				var keep := ""
				for k: String in DJ:
					if DJ[k] == jong:
						keep = k[0]
						move = k[1]
				out += _syllable(cho, jung, keep)
				cho = move
				jung = j
				jong = ""
		else:
			if jung == "":
				out += _syllable(cho, jung, jong)
				cho = j
			elif cho == "":
				out += _syllable(cho, jung, jong)
				cho = j
				jung = ""
			elif jong == "":
				if JONG.has(j):
					jong = j
				else:
					out += _syllable(cho, jung, jong)
					cho = j
					jung = ""
			elif DJ.has(jong + j):
				jong = DJ[jong + j]
			else:
				out += _syllable(cho, jung, jong)
				cho = j
				jung = ""
				jong = ""
	return out + _syllable(cho, jung, jong)
