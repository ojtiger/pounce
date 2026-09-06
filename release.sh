#!/bin/bash
# 릴리스 한 판: 버전 올리고, 공증 빌드하고, GitHub 릴리스를 만들고, 홈브루 cask 를 갱신한다.
# 되돌릴 수 없는 일(태그, 릴리스, push)은 하기 전에 반드시 묻는다.
set -euo pipefail
cd "$(dirname "$0")"

PLIST=src/Info.plist
TAP_REPO=ojtiger/homebrew-tap
NOTARY_PROFILE=${NOTARY_PROFILE:-pounce}

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
ask() { # ask "질문" -> yes 면 0
  local answer
  read -r -p "$1 [y/N] " answer
  [[ "$answer" == [yY] ]]
}

current=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")
IFS=. read -r major minor patch <<<"$current"
suggested="$major.$minor.$((patch + 1))"

say "현재 버전: $current"
read -r -p "다음 버전 [$suggested]: " next
next=${next:-$suggested}
[[ "$next" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "버전은 x.y.z 형식이어야 합니다: $next"
[[ "$next" != "$current" ]] || die "현재 버전과 같습니다."

# ── 나갈 수 있는 상태인지
if [[ -n "$(git status --porcelain)" ]]; then
  warn "커밋 안 된 변경이 있습니다:"
  git status --short
  ask "이대로 진행할까요? (버전 올린 것과 함께 커밋됩니다)" || die "중단."
fi

signing_ok=true
security find-identity -v -p codesigning | grep -q "Developer ID Application" || {
  warn "Developer ID Application 인증서가 없습니다."
  warn "  → Apple Development 로 서명하면 받는 쪽 Gatekeeper 가 막고,"
  warn "    기존 사용자의 손쉬운 사용 권한이 날아갑니다(서명 주체가 바뀌므로)."
  signing_ok=false
}
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 || {
  warn "공증 프로필 '$NOTARY_PROFILE' 이 없습니다. xcrun notarytool store-credentials 로 만드세요."
  signing_ok=false
}
if ! $signing_ok; then
  ask "공증 없이 make package 로 만들까요? (내부 테스트용)" || die "중단."
  BUILD_TARGET=package
else
  BUILD_TARGET=notarize
fi

# ── 버전 박기: 앱과 소개 페이지가 같은 숫자를 말해야 한다
say "버전 $current → $next"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $next" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $next" "$PLIST" 2>/dev/null || true
sed -i '' "s/^VERSION = \".*\"/VERSION = \"$next\"/" docs/build.py
python3 docs/build.py >/dev/null

say "빌드: make $BUILD_TARGET"
make "$BUILD_TARGET"

ZIP="dist/Pounce-$next.zip"
[[ -f "$ZIP" ]] || die "$ZIP 이 없습니다."
SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
say "$ZIP  ($(du -h "$ZIP" | cut -f1))"
echo "sha256: $SHA"

# ── 커밋과 태그
say "커밋 · 태그"
git add -A
git commit -m "$next"
ask "v$next 태그를 만들고 push 할까요?" || die "중단. (커밋은 남아 있습니다)"
git tag "v$next"
git push
git push --tags

# ── GitHub 릴리스
if command -v gh >/dev/null 2>&1; then
  say "GitHub 릴리스 생성"
  gh release create "v$next" "$ZIP" --title "Pounce $next" --notes "$(git log --format='- %s' "$(git describe --tags --abbrev=0 "v$next^" 2>/dev/null || echo HEAD~5)".."v$next" | grep -v '^- '"$next"'$' || echo "- $next")"
else
  warn "gh 가 없어 릴리스는 직접 만드셔야 합니다."
  echo "  https://github.com/ojtiger/pounce/releases/new?tag=v$next"
  echo "  제목: Pounce $next / 첨부: $ZIP"
  ask "릴리스를 올리셨나요? (cask 갱신으로 넘어갑니다)" || exit 0
fi

# ── 홈브루 cask
say "홈브루 cask 갱신"
if command -v gh >/dev/null 2>&1; then
  work=$(mktemp -d)
  gh repo clone "$TAP_REPO" "$work/tap" -- --quiet
  cask="$work/tap/Casks/pounce.rb"
  sed -i '' "s/version \".*\"/version \"$next\"/; s/sha256 \".*\"/sha256 \"$SHA\"/" "$cask"
  (cd "$work/tap" && git add -A && git commit -q -m "pounce $next" && git push -q)
  rm -rf "$work"
  echo "완료: $TAP_REPO 의 pounce.rb 가 $next 로 갱신됐습니다."
else
  echo "$TAP_REPO 의 Casks/pounce.rb 를 이렇게 고치세요."
  echo "  version \"$next\""
  echo "  sha256 \"$SHA\""
fi

say "끝. brew install --cask $TAP_REPO/pounce 로 확인해 보세요."
