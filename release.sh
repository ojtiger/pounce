#!/bin/bash
# 릴리스 한 판. 새 버전 번호만 정하면 나머지는 알아서 간다.
#   버전 박기 → 빌드 → 커밋·태그·push → GitHub 릴리스 → 홈브루 cask 갱신 → 확인
# 되돌릴 수 없는 일은 하기 전에 묻고, 잘못된 상태(밀린 push, 낮은 버전)는 미리 막는다.
set -euo pipefail
cd "$(dirname "$0")"

PLIST=src/Info.plist
REPO=ojtiger/pounce
TAP=ojtiger/homebrew-tap
NOTARY_PROFILE=${NOTARY_PROFILE:-pounce}
# 릴리스는 팀 하나로만 나가야 한다. 팀이 바뀌면 macOS 가 다른 앱으로 보아 사용자의 손쉬운 사용
# 권한이 날아가고, 업데이터도 "다른 개발자가 서명한 빌드"라며 거부한다. 0.3.0 이 나간 팀에 맞춘다.
RELEASE_TEAM=${RELEASE_TEAM:-VXR4D4G8N4}

step() { printf '\n\033[1m▸ %s\033[0m\n' "$*"; }
warn() { printf '\033[33m! %s\033[0m\n' "$*"; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32m✓ %s\033[0m\n' "$*"; }
ask()  { local a; read -r -p "$(printf '\033[1m? %s [y/N] \033[0m' "$1")" a; [[ "$a" == [yY] ]]; }
higher() { [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" == "$1" ]]; }

# 이 맥에 있는 서명 인증서 중 팀이 맞는 것의 해시. 같은 애플 ID 라도 팀이 여럿이면
# 인증서도 여럿이고, Makefile 은 그냥 첫 번째를 집는다. 팀으로 골라야 한다.
identity_for_team() {
  local team=$1 line hash cn ou
  while IFS= read -r line; do
    hash=${line%% *}; cn=${line#* }
    ou=$(security find-certificate -c "$cn" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null |
         tr ',' '\n' | sed -n 's/^ *OU=//p' | head -1)
    [[ "$ou" == "$team" ]] && { printf '%s' "$hash"; return 0; }
  done < <(security find-identity -v -p codesigning | sed -n 's/^ *[0-9]*) \([A-F0-9]*\) "\(.*\)"$/\1 \2/p')
  return 1
}

# ── 1. 지금 상태
current=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")
branch=$(git rev-parse --abbrev-ref HEAD)
step "현재 버전 $current  (브랜치 $branch)"
[[ "$branch" == "main" ]] || ask "main 이 아닙니다. 계속할까요?" || die "중단."

git fetch -q origin
ahead=$(git rev-list --count origin/"$branch".."$branch" 2>/dev/null || echo 0)
behind=$(git rev-list --count "$branch"..origin/"$branch" 2>/dev/null || echo 0)
[[ "$behind" == "0" ]] || die "원격이 $behind 커밋 앞서 있습니다. git pull 먼저 하세요."
[[ "$ahead" == "0" ]] || warn "push 안 된 커밋 $ahead 개 — 이번에 함께 올라갑니다."
dirty=$(git status --porcelain)
[[ -z "$dirty" ]] || { warn "커밋 안 된 변경:"; git status --short; }

# ── 2. 새 버전
IFS=. read -r ma mi pa <<<"$current"
suggested="$ma.$mi.$((pa + 1))"
read -r -p "$(printf '\033[1m새 버전 [%s]: \033[0m' "$suggested")" next
next=${next:-$suggested}
[[ "$next" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "x.y.z 형식이어야 합니다: $next"
higher "$next" "$current" || die "$next 은 $current 보다 낮거나 같습니다. 버전은 되돌릴 수 없습니다."

if git rev-parse -q --verify "refs/tags/v$next" >/dev/null || git ls-remote --tags origin "v$next" | grep -q .; then
  warn "v$next 태그가 이미 있습니다(릴리스 없이 남은 것일 수 있음)."
  ask "지우고 다시 만들까요?" || die "중단."
  git tag -d "v$next" 2>/dev/null || true
  git push --delete origin "v$next" 2>/dev/null || true
fi

# ── 3. 서명 채비
# 공증은 유료 개발자 프로그램이 있어야 한다. 없으면 지금까지처럼 package 로 낸다 — 정상 경로다.
target=package
if security find-identity -v -p codesigning | grep -q "Developer ID Application" &&
   xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  target=notarize
  ok "Developer ID + 공증 프로필 확인"
fi

# ── 4. 버전 박고 빌드
step "$current → $next"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $next" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $next" "$PLIST" 2>/dev/null || true
sed -i '' "s/^VERSION = \".*\"/VERSION = \"$next\"/" docs/build.py
python3 docs/build.py >/dev/null
ok "앱과 소개 페이지에 $next 반영"

IDENTITY_ARG=()
if hash=$(identity_for_team "$RELEASE_TEAM"); then
  IDENTITY_ARG=(IDENTITY="$hash")
  ok "서명 인증서: 팀 $RELEASE_TEAM (${hash:0:8}…)"
else
  warn "팀 $RELEASE_TEAM 인증서가 이 맥에 없습니다. Xcode > Settings > Accounts 에서 그 팀으로"
  warn "  Apple Development 인증서를 발급받거나, 다른 맥에서 .p12 로 내보내 가져오세요."
fi

step "빌드 (make $target)"
make "$target" "${IDENTITY_ARG[@]}"
ZIP="dist/Pounce-$next.zip"
[[ -f "$ZIP" ]] || die "$ZIP 이 없습니다."

built_team=$(codesign -dv Pounce.app 2>&1 | sed -n 's/^TeamIdentifier=//p')
if [[ "$built_team" != "$RELEASE_TEAM" ]]; then
  warn "이 빌드의 서명 팀은 ${built_team:-없음} 인데, 릴리스 팀은 $RELEASE_TEAM 입니다."
  warn "  이대로 내면 쓰던 사람들의 손쉬운 사용 권한이 전부 풀리고, 자동 업데이트가 끊깁니다."
  warn "  → $RELEASE_TEAM 쪽 인증서를 이 맥 키체인에 넣고 다시 돌리는 게 맞습니다."
  warn "    (키체인 접근 > 내 인증서 > 개인 키까지 .p12 로 내보내 다른 맥에서 두 번 클릭)"
  warn "  팀을 이쪽으로 옮기기로 정했다면 RELEASE_TEAM=$built_team ./release.sh 로 돌리세요."
  ask "그래도 이 팀으로 낼까요?" || die "중단. 버전은 올라갔지만 커밋 전이라 git checkout 으로 되돌릴 수 있습니다."
fi

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
ok "$ZIP  $(du -h "$ZIP" | cut -f1)  sha256 ${SHA:0:12}…"

# ── 5. 올리기
step "커밋 · 태그 · push"
git add -A
git commit -q -m "$next"
ask "v$next 로 태그하고 push 할까요? (여기부터 되돌리기 어렵습니다)" || die "중단. 커밋은 남아 있습니다."
git tag "v$next"
git push -q && git push -q --tags
ok "push 완료"

step "GitHub 릴리스"
if command -v gh >/dev/null 2>&1; then
  notes=$(git log --format='- %s' "$(git describe --tags --abbrev=0 "v$next^" 2>/dev/null)".."v$next" 2>/dev/null | grep -vx "- $next" || true)
  gh release create "v$next" "$ZIP" --repo "$REPO" --title "Pounce $next" --notes "${notes:-- $next}"
  ok "릴리스 v$next 생성"
else
  warn "gh 가 없어 릴리스는 브라우저에서 올리셔야 합니다."
  open "https://github.com/$REPO/releases/new?tag=v$next&title=Pounce+$next"
  open -R "$ZIP"
  echo "  Finder 의 zip 을 첨부하고 Publish release 를 누르세요."
  until ask "올리셨나요?"; do :; done
fi

step "홈브루 cask"
if command -v gh >/dev/null 2>&1; then
  work=$(mktemp -d)
  gh repo clone "$TAP" "$work/tap" -- --quiet
  sed -i '' "s/version \".*\"/version \"$next\"/; s/sha256 \".*\"/sha256 \"$SHA\"/" "$work/tap/Casks/pounce.rb"
  (cd "$work/tap" && git commit -qam "pounce $next" && git push -q)
  rm -rf "$work"
  ok "cask $next 반영"
else
  echo "  version \"$next\""
  echo "  sha256 \"$SHA\""
  open "https://github.com/$TAP/edit/main/Casks/pounce.rb"
  until ask "두 줄 고치고 커밋하셨나요?"; do :; done
fi

# ── 6. 확인
step "확인"
url="https://github.com/$REPO/releases/download/v$next/Pounce-$next.zip"
code=$(curl -s -o /dev/null -w '%{http_code}' -L "$url")
[[ "$code" == "200" ]] && ok "zip 내려받기 가능" || warn "zip 이 아직 안 보입니다 (HTTP $code) — 몇 초 뒤 다시 확인해 보세요."
ok "끝. 깔린 앱들은 하루 안에 스스로 $next 로 올라갑니다."
echo "  새로 까는 사람: brew update && brew install --cask $TAP/pounce"
