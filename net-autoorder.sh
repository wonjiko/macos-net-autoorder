#!/bin/bash
# 온라인 서비스마다 ping을 보내 손실률, RTT 순으로 네트워크 서비스 순서를 다시 매긴다.
# 사용법: net-autoorder.sh [--dry-run | --selftest]
set -u
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

TARGET=1.1.1.1
COUNT=30            # ping 횟수이자 트래픽 측정 구간(초)
HOLD_LOSS=20        # 1순위 손실률(%)이 이 값 미만이고
HOLD_RATE=102400    # 1순위 트래픽(B/s)이 이 값을 넘으면 순서를 유지한다
LOSS_MARGIN=5       # 손실률 차이(%p)가 이보다 작으면 RTT로 비교한다
RTT_RATIO=0.7       # RTT가 상대의 70% 미만일 때만 앞선다고 본다

log() { echo "$(date '+%F %T') $*"; }

# 현재 순서대로 "서비스명<TAB>장치"를 출력한다. 비활성 서비스는 "(*) 이름"으로 나온다.
services() {
  networksetup -listnetworkserviceorder | awk '
    /^\([0-9*]+\) / { sub(/^\([0-9*]+\) /, ""); name = $0; next }
    /Device:/ { dev = $0; sub(/.*Device: ?/, "", dev); sub(/\).*/, "", dev); print name "\t" dev }'
}

# 받은 바이트 + 보낸 바이트 누적값. MAC 주소 칸이 빈 인터페이스가 있어 뒤에서부터 센다.
bytes() { netstat -ib -I "$1" 2>/dev/null | awk '/<Link#/ { print $(NF-4) + $(NF-1); exit }'; }

# "손실률 평균RTT"를 출력한다. 응답이 하나도 없으면 RTT는 999999.
probe() {
  ping -q -b "$1" -c "$COUNT" -t $((COUNT + 5)) "$TARGET" 2>/dev/null | awk '
    /packet loss/ { for (i = 1; i <= NF; i++) if ($i ~ /%$/) { loss = $i; sub(/%/, "", loss) } }
    /round-trip/  { split($4, r, "/"); rtt = r[2] }
    END { if (loss == "") loss = 100; if (rtt == "") rtt = 999999; print loss, rtt }'
}

# stdin: 현재 순서의 "이름<TAB>손실률<TAB>RTT<TAB>온라인(1/0)", $1: 1순위 트래픽(B/s)
# stdout: 새 순서의 이름 목록
decide() {
  awk -F'\t' -v rate="$1" -v HL="$HOLD_LOSS" -v HR="$HOLD_RATE" -v M="$LOSS_MARGIN" -v R="$RTT_RATIO" '
    { n++; name[n] = $1; loss[n] = $2; rtt[n] = $3; on[n] = $4; o[n] = n }
    function better(a, b) {
      if (loss[b] - loss[a] >= M) return 1
      if (loss[a] - loss[b] >= M) return 0
      return rtt[a] < rtt[b] * R
    }
    END {
      for (i = 1; i <= n; i++) if (on[i]) { p = i; break }
      hold = p && loss[p] < HL && rate > HR
      # 확실히 앞설 때만 한 칸씩 올리는 삽입 정렬이라, 비슷한 서비스끼리는 현재 순서가 유지된다
      if (!hold) for (i = 2; i <= n; i++)
        for (j = i; j > 1 && better(o[j], o[j-1]); j--) { t = o[j]; o[j] = o[j-1]; o[j-1] = t }
      for (i = 1; i <= n; i++) print name[o[i]]
    }'
}

selftest() {
  local fail=0
  check() {  # $1 설명, $2 트래픽, $3 기대 순서, stdin 측정값
    local got; got=$(decide "$2" | paste -sd, -)
    if [ "$got" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: $got (기대 $3)"; fail=1; fi
  }
  printf 'eth\t0\t10\t1\nwifi\t0\t8\t1\n'   | check "RTT 차이가 작으면 현재 순서 유지" 0 eth,wifi
  printf 'eth\t0\t30\t1\nwifi\t0\t10\t1\n'  | check "RTT가 확실히 낮으면 앞선다" 0 wifi,eth
  printf 'eth\t10\t10\t1\nwifi\t0\t8\t1\n'  | check "사용 중이고 손실이 작으면 보류" 500000 eth,wifi
  printf 'eth\t10\t10\t1\nwifi\t0\t8\t1\n'  | check "사용 중이 아니면 손실 낮은 쪽이 앞선다" 0 wifi,eth
  printf 'eth\t30\t10\t1\nwifi\t0\t8\t1\n'  | check "손실이 크면 사용 중이어도 바꾼다" 500000 wifi,eth
  printf 'eth\t100\t999999\t0\nwifi\t0\t8\t1\ntether\t100\t999999\t1\n' \
    | check "응답 없는 서비스는 상대 순서를 유지하며 뒤로" 0 wifi,eth,tether
  printf 'eth\t100\t999999\t0\nwifi\t10\t8\t1\nlte\t0\t40\t1\n' \
    | check "오프라인 1위는 건너뛰고 첫 온라인 서비스로 보류 판정" 500000 eth,wifi,lte
  return $fail
}

main() {
  local dry=0 primary="" b0=0 t0=0 b1 rate=0 i name dev loss rtt
  case "${1:-}" in
    --selftest) selftest; exit ;;
    --dry-run) dry=1 ;;
  esac

  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  services > "$tmp/order"

  i=0
  while IFS=$'\t' read -r name dev; do
    i=$((i + 1))
    [ -n "$dev" ] && ipconfig getifaddr "$dev" >/dev/null 2>&1 || continue
    if [ -z "$primary" ]; then primary=$dev; b0=$(bytes "$dev"); t0=$(date +%s); fi
    probe "$dev" > "$tmp/$i" &
  done < "$tmp/order"
  wait

  if [ -n "$primary" ]; then
    b1=$(bytes "$primary")
    local elapsed=$(( $(date +%s) - t0 )); [ "$elapsed" -lt 1 ] && elapsed=1
    rate=$(( (b1 - b0) / elapsed ))
    [ "$rate" -lt 0 ] && rate=0  # 측정 중 링크가 다시 올라와 카운터가 초기화된 경우
  fi

  i=0
  while IFS=$'\t' read -r name dev; do
    i=$((i + 1))
    if [ -f "$tmp/$i" ]; then read -r loss rtt < "$tmp/$i"; printf '%s\t%s\t%s\t1\n' "$name" "$loss" "$rtt"
    else printf '%s\t100\t999999\t0\n' "$name"; fi
  done < "$tmp/order" > "$tmp/rows"

  decide "$rate" < "$tmp/rows" > "$tmp/new"
  local summary
  summary="rate=${rate}B/s $(awk -F'\t' '$4 { printf "[%s %s%% %sms] ", $1, $2, $3 }' "$tmp/rows")"

  if cut -f1 "$tmp/order" | cmp -s - "$tmp/new"; then
    log "keep  $summary"
    return
  fi
  log "apply $summary-> $(paste -sd, - < "$tmp/new")"
  [ "$dry" = 1 ] && return

  local order=()
  while IFS= read -r name; do order+=("$name"); done < "$tmp/new"
  networksetup -ordernetworkservices "${order[@]}"
}

main "$@"
