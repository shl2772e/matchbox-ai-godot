# CLAUDE.md

웹 앱 **성냥갑 AI**(`C:\antigravity\matchbox-ai`, MENACE 1961 틱택토 강화학습 체험)를 Godot 4(2D)로 옮기고 애니메이션을 더한 버전이다. 규칙·문구·디자인(시안 A "1961 성냥갑 연구실")의 기준은 웹 앱의 PRD(`matchbox-ai/docs/성냥갑AI(틱택토 강화학습) PRD.md`)다. 웹 앱 코드는 참조만 하고 고치지 않는다.

## 범위 (v0.1)
- 만든 것: 대기 → 안내 4장(신문·앨범·구슬·상과 벌) → 놀이(3판) → 배우는 순간 → 결과, 60초 무입력 시 대기로, 저장(두뇌·오늘 기록·설정), 소리.
- 문구는 대본 A "오늘 내가 AI 선생님"(`docs/설명 대본 시안.md`). 학생은 "나", AI는 "AI"로 부른다 ("네/너" 금지).
- 안내 사진은 CC BY-SA라 출처를 화면과 `docs/CREDITS.md`에 적는다. 사진을 바꾸면 둘 다 고친다.
- 아직 없음: 선생님 메뉴(AI 고르기, 판 수, 확률 표시 등), 관객 화면(외부 모니터), 두뇌 파일 저장/불러오기.

## 구조
- `scripts/domain/` 순수 규칙 (노드·화면 없음): `ttt.gd`(판·승부·대칭), `menace.gd`(상자·구슬·두기·배우기), `self_play.gd`(혼자 두기·AI 단계), `today.gd`, `rng.gd`(mulberry32, 웹 앱과 같은 수열 — 같은 시드면 웹 앱과 같은 AI).
- `scripts/ui/kit.gd` 색·글꼴·그림 도구. 색은 여기 상수만 쓴다. `Kit.R`(27px)이 웹의 1rem.
- `scripts/ui/` 그리는 부품: `board_view.gd`(판), `matchbox_view.gd`(성냥갑·서랍), `drawn.gd`.
- `scripts/screens/` 화면. 위치는 `relayout()`에서 직접 계산하고, 세로 화면(`portrait()`)이면 배치만 바꾼다.
- `scripts/main.gd` 화면 흐름. `scripts/sfx.gd`(자동 로드 `Sfx`) 소리를 코드로 만든다.
- 화면 기준 1920×1080, stretch `canvas_items` + `expand`. 렌더러는 GL Compatibility(현장 PC 호환).

## 규칙
- 화면 글자에 이모지·←/→를 쓰지 않는다. 문구는 초등 3학년이 읽을 수 있게.
- AI 차례 연출은 1.2초 안: 서랍 열림 0.45초 → 구슬 떠오름 0.2초 → 판으로 날아감 0.4초. 뽑기·당첨처럼 보이는 연출(번쩍임, 뜸 들이기) 금지.
- 줄바꿈이 있는 글자는 `Kit.label(..., wrap=true)`로 만들고 `Kit.place()`로 놓는다 (낱말 중간에서 안 끊기게, 높이는 글꼴로 잼).
- GDScript에서 여러 줄 람다를 함수 인자로 넘기지 않는다. 메서드 + `bind()`를 쓴다.

## 명령어 (Godot 경로: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\`)
- 실행: `run.bat` (전체화면, F11로 창 모드). **run.bat에는 한글을 쓰지 않는다** (cmd가 UTF-8 한글을 읽다 깨진다), 줄 끝은 CRLF.
- 편집기: `Godot_v4.7.2-stable_win64.exe --path . -e`
- 테스트: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd`
- 화면 점검(3판 자동 진행 후 PNG 저장): `... --path . --resolution 1920x1080 -- --qa=<폴더>` (세로는 `1080x1920`). 저장된 두뇌는 끝나면 되돌린다.
- 스크립트를 새로 만들었으면 먼저 `--headless --path . --import`로 클래스 목록을 갱신한다.
- 실행 파일 내보내기: `... --headless --path . --export-release "Windows Desktop" build/matchbox-ai.exe` → `build/matchbox-ai.exe` 하나(PCK 포함, 약 120MB)를 현장 PC에 복사하면 된다. 내보낸 실행 파일은 전체화면으로 시작한다. `tests/`·`docs/`는 빼고 넣는다(export_presets.cfg). export templates는 `%APPDATA%\Godot\export_templates\4.7.2.stable\`에 Windows x86_64 4개만 넣었다(없으면 GitHub 릴리스의 `Godot_v4.7.2-stable_export_templates.tpz`에서 꺼낸다).
- 저장 파일(`%APPDATA%\matchbox-ai-godot\*.json`)은 `.tmp`에 쓴 뒤 `.bak`을 남기고 바꾼다. 본 파일이 깨지면 `.bak`을 읽는다.
