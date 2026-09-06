#!/bin/bash
# 서명에 쓸 인증서 해시를 고른다. 같은 애플 ID 라도 팀이 여럿이면 인증서도 여럿이고,
# 팀이 섞이면 macOS 가 다른 앱으로 보아 사용자의 권한이 풀리고 자동 업데이트가 끊긴다.
# 그래서 이름이 아니라 인증서의 OU(팀)로 고른다. 없으면 ad-hoc('-')으로 떨어져 개발은 굴러간다.
set -uo pipefail
team=${1:-VXR4D4G8N4}

while IFS= read -r line; do
  hash=${line%% *}; cn=${line#* }
  ou=$(security find-certificate -c "$cn" -p 2>/dev/null |
       openssl x509 -noout -subject 2>/dev/null | tr ',' '\n' | sed -n 's/^ *OU=//p' | head -1)
  if [[ "$ou" == "$team" ]]; then printf '%s' "$hash"; exit 0; fi
done < <(security find-identity -v -p codesigning 2>/dev/null |
         sed -n 's/^ *[0-9]*) \([A-F0-9]*\) "\(.*\)"$/\1 \2/p')

printf '%s' "-"
