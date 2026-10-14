#!/bin/bash
# 사용법: sudo ./install.sh [uninstall]
set -eu
cd "$(dirname "$0")"

BIN=/usr/local/libexec/net-autoorder.sh
PLIST=/Library/LaunchDaemons/local.net-autoorder.plist

launchctl bootout system "$PLIST" 2>/dev/null || true

if [ "${1:-}" = uninstall ]; then
  rm -f "$BIN" "$PLIST"
  echo "제거했다. 로그 /var/log/net-autoorder.log 는 남겨 둔다."
  exit
fi

# launchd는 ~/Desktop 아래 파일을 읽지 못하므로 링크하지 않고 복사한다
install -d /usr/local/libexec
install -m 755 -o root -g wheel net-autoorder.sh "$BIN"
install -m 644 -o root -g wheel local.net-autoorder.plist "$PLIST"
launchctl bootstrap system "$PLIST"
echo "설치했다. 로그: tail -f /var/log/net-autoorder.log"
