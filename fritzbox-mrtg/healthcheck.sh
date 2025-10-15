#!/bin/sh
# Healthcheck for fritzbox-mrtg container (Alpine)
# - Checks RRD freshness
# - Verifies rrdtool graphing
# - Optionally checks Nginx/CGI endpoint

set -eu

TARGET="${MRTG_TARGET_NAME:-fritzbox}"
RRD="/srv/www/htdocs/${TARGET}.rrd"

# Determine interval (minutes) -> seconds
INTERVAL_MIN="$(awk 'tolower($1)=="interval:"{print $2; exit}' /etc/mrtg.cfg 2>/dev/null || true)"
if [ -z "${INTERVAL_MIN}" ]; then
  # Fallback to POLL_INTERVAL env or default 300s => 5 min
  PI="${POLL_INTERVAL:-300}"
  # guard zero/empty
  case "$PI" in ''|*[!0-9]*) PI=300;; esac
  INTERVAL_MIN=$((PI / 60))
  [ "$INTERVAL_MIN" -lt 1 ] && INTERVAL_MIN=1
fi
INTERVAL_SEC=$((INTERVAL_MIN * 60))

# Allow override for maximum allowed age in seconds
HC_MAX_AGE_SEC="${HC_MAX_AGE_SEC:-$((INTERVAL_SEC * 2 + 60))}"

# 1) RRD exists?
if [ ! -f "$RRD" ]; then
  echo "health: missing RRD: $RRD" >&2
  exit 1
fi

# 2) RRD fresh enough?
LASTLINE="$(rrdtool lastupdate "$RRD" 2>/dev/null | tail -n 1 || true)"
TS="${LASTLINE%%:*}"
case "$TS" in ''|*[!0-9]*) echo "health: invalid lastupdate: $LASTLINE" >&2; exit 1;; esac
NOW="$(date +%s)"
AGE=$((NOW - TS))
if [ "$AGE" -gt "$HC_MAX_AGE_SEC" ]; then
  echo "health: stale RRD (age=${AGE}s > ${HC_MAX_AGE_SEC}s)" >&2
  exit 1
fi

# 3) rrdtool graph smoke test (ensures fonts/options OK)
if ! rrdtool graph /tmp/health.png -s -1h -e now \
  DEF:in="$RRD":ds0:AVERAGE LINE1:in#00ff00:In \
  --border 0 \
  -c FONT#e0e0e0 -c AXIS#aaaaaa -c FRAME#888888 \
  -c GRID#444444 -c MGRID#666666 -c BACK#202020 -c CANVAS#282828 \
  >/dev/null 2>&1; then
  echo "health: rrdtool graph failed" >&2
  exit 1
fi
rm -f /tmp/health.png 2>/dev/null || true

# 4) Web/CGI check (if webserver enabled)
if [ "${RUN_WEBSERVER:-1}" = "1" ]; then
  BASE="${HC_URL_BASE:-http://127.0.0.1}"
  # root reachable
  if ! curl -fsS -m 3 "$BASE/" >/dev/null; then
    echo "health: nginx root not reachable" >&2
    exit 1
  fi
  # 14all CGI reachable (PNG request)
  if ! curl -fsS -m 5 -o /dev/null \
    "$BASE/cgi-bin/14all.cgi?log=${TARGET}&png=day.s&small=1"; then
    echo "health: 14all.cgi not reachable" >&2
    exit 1
  fi
fi

echo "healthy: age=${AGE}s interval=${INTERVAL_MIN}m"
exit 0