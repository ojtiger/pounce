# Pounce

macOS 알림 배너를 화면 원하는 자리로 옮겨 카드로 다시 그리는 메뉴막대 앱.
Swift/AppKit, 의존성 없음, `swiftc` + Makefile 로 빌드한다.

```
src/App.swift          앱 본체, 카드/워처/설정 연결, 테스트 알림, 자동 업데이트 기동
src/Watcher.swift      알림센터를 AX 로 감시, 배너 창을 화면 밖으로 치우고 내용을 읽는다
src/Card.swift         카드 그리기와 배치, 액션 알약
src/Settings.swift     설정 창(위치·테마·설정·정보 탭)과 UserDefaults
src/Localization.swift 화면 문자열 표. 한국어 원문이 키, 17개 언어
src/Updater.swift      새 버전 확인·설치·재실행
src/AX.swift           접근성 헬퍼와 로그
docs/                  소개 페이지(GitHub Pages). build.py 로 4개 국어 생성
release.sh             배포 한 판
signing-identity.sh    서명 인증서를 팀으로 고른다
```

## 서명 팀을 섞지 말 것

같은 애플 ID 에 팀이 둘이다.

| 팀 | 정체 | 용도 |
|---|---|---|
| `VXR4D4G8N4` | 개인 팀(중호랑이 오) | **릴리스는 무조건 이쪽.** 0.3.0 부터 이걸로 나갔다 |
| `9BG43PHD7W` | 고객사 조직 팀 | 개인 앱에 쓰지 않는다 |

팀이 바뀌면 macOS 가 다른 앱으로 보아 **사용자의 손쉬운 사용 권한이 전부 풀리고**, 업데이터도
팀 불일치를 이유로 설치를 거부한다. 되돌리기가 가장 비싼 실수다.

`signing-identity.sh` 가 인증서 이름이 아니라 **OU(팀)** 로 골라주고 Makefile 과 release.sh 가
같이 쓴다. 새 맥에서 작업하려면 Xcode > Settings > Accounts > 개인 팀 > Manage Certificates
에서 Apple Development 인증서부터 발급받는다. 확인은 `./signing-identity.sh` 가 해시를
뱉는지 보면 된다(`-` 면 없는 것).

## 배포

```sh
./release.sh        # 현재 버전을 보여주고 새 버전을 묻는다
```

버전 역행·밀린 push·유령 태그·팀 불일치를 먼저 막고, 빌드 → 커밋·태그·push → GitHub 릴리스
→ 홈브루 cask(ojtiger/homebrew-tap) 까지 간다. `gh` 가 필요하다. 중간에 죽으면 파일에 박아둔
버전을 되돌린다.

Developer ID 인증서가 없어 **공증은 하지 않는다.** `make package` 경로가 정상이고, 받는 쪽은
처음 한 번 우클릭 > 열기가 필요하다. 인증서가 만료돼도 서명이 살도록 `--timestamp` 를 넣었다.

## 자동 업데이트

하루 한 번 확인 → 내려받아 서명과 팀 검사 → 번들 교체 → 재실행 → 돌아온 뒤 알림 한 번.
누를 것이 없다. 설정에서 끌 수 있고, 정보 탭에 수동 확인 버튼이 따로 있다.

확인은 `github.com/ojtiger/pounce/releases.atom` 을 읽는다. `api.github.com` 은 익명 요청이
**시간당 60회·IP** 라 공인 IP 를 나눠 쓰는 사무실에서는 403 이 뜬다(실측). 0.3.3 까지는 API 를
써서 그런 곳에서는 확인이 실패한다.

## 개발

```sh
make install    # /Applications 에 덮어쓰기. 실행 중이면 죽였다가 다시 띄워야 한다
make build      # 서명까지만
```

- 로그는 `~/Library/Logs/pounce.log`. 설정 > 설정 탭에서 디버그 로그를 켜면 배너 트리까지 남는다.
- 앱을 갈아끼우면 손쉬운 사용 권한이 떨어질 수 있다. 설정 > 설정 탭 > 접근성 열기로 다시 켠다.
- 소개 페이지 문구는 `docs/build.py` 에서 고치고 `python3 docs/build.py` 로 4개 국어를 다시 찍는다.
  HTML 을 직접 고치면 다음 생성 때 날아간다.

## 카드에 그리는 버튼

배너가 주는 액션 중 **카드 클릭과 겹치는 것은 그리지 않는다** — 닫기(모서리 X 가 그 역할),
세부사항 보기(카드가 이미 본문을 펼침), 앱 열기류(Show/보기/表示…). 접근성이 주는 원본은
무엇을 하든 `Name:답장\nTarget:0x0\nSelector:(null)` 로 모양이 같아 이름으로 가를 수밖에 없고,
목록에 없는 이름은 한 번 눌러보고 배운다(누른 뒤 배너가 사라지면 앱만 여는 버튼).

답장처럼 자기 UI 를 여는 버튼은 배너가 살아남는다. 그때는 진짜 배너를 카드가 서 있던 자리로
중앙을 맞춰 데려온다. 그 UI 는 알림센터가 자기 안에 그리는 것이라 우리가 다시 그릴 수 없다.
