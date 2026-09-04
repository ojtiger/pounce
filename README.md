# Pounce

macOS 가 우측 상단에 그리는 알림 배너를 그 순간 가로채 **주 모니터 정중앙**에 리퀴드 글래스 카드로 보여줍니다.
알림 자체는 바꾸지 않습니다. 집중 모드, 방해금지, 소리, 알림센터 기록, 클릭 동작 전부 macOS 규칙 그대로이고 위치와 표현만 다릅니다.

- 접근성 API 로 알림센터 배너 창을 감시하고, 화면에 들어오기 전에 치운 뒤 내용을 읽습니다.
- 카드는 원본 배너와 같이 살고 같이 사라집니다. 같은 앱 알림은 카드 하나에 묶입니다.
- 떠 있는 알림("알림" 스타일)은 10초 뒤 우측 상단 제자리로 돌려줍니다.
- macOS 26 은 NSGlassEffectView, 그 이전은 서리 유리. 다크/라이트와 강조 색상은 시스템을 따릅니다.
- 메뉴 막대 아이콘은 숨길 수 있습니다. 숨긴 뒤 Pounce 를 다시 실행하면 설정 창이 열립니다.
- 비공개 접근성 구조에 기대므로 macOS 업데이트 때 깨질 수 있습니다. 깨지면 원래 배너가 그냥 우측 상단에 뜹니다.

## 다른 맥에서 받기 (예: 회사)

```sh
git clone https://github.com/ojtiger/pounce.git
cd pounce
make install          # Xcode 필요. 서명은 그 맥의 Apple Development 인증서, 없으면 ad-hoc
open -a Pounce   # 접근성 권한 허용 → 끝
```

또는 GitHub Releases 의 zip 을 받아 /Applications 에 넣고, 처음 한 번은 시스템 설정 > 개인정보 보호 및 보안 > "그래도 열기"(공증 전이라 Gatekeeper 가 막음).

## 빌드 / 설치 (개발)

```sh
make install        # 빌드 후 /Applications/Pounce.app 교체
open -a Pounce # 첫 실행 때 접근성 권한을 묻습니다
```

## 배포

Mac App Store 는 불가합니다(샌드박스 필수 + 접근성 API 용도 심사). Developer ID 직배포만 가능합니다.

1. Apple Developer Program 가입 후 Xcode 에서 **Developer ID Application** 인증서 발급.
2. 공증 자격 저장(한 번만):
   `xcrun notarytool store-credentials pounce --apple-id <Apple ID> --team-id <팀 ID> --password <앱 암호>`
3. `make notarize` → `dist/Pounce-<버전>.zip` 과 `.dmg` 가 나옵니다. 유니버설 바이너리, 하드닝 런타임, 공증 스테이플 포함.
4. GitHub Releases 에 올리고, 원하면 Homebrew tap 에 cask 를 둡니다.

버전은 `src/Info.plist` 의 CFBundleShortVersionString 하나만 올리면 됩니다.
