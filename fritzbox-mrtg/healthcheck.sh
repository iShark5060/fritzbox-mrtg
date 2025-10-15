#!/bin/sh
set -eu

TARGET="${MRTG_TARGET_NAME:-fritzbox}"
RRD="/srv/www/htdocs/${TARGET}.rrd"

# Detect HTTPS from USE_SSL unless overridden
USE_SSL="${USE_SSL:-0}"
SCHEME="${HC_SCHEME:-$( [ "$USE_SSL" = "1" ] && echo https || echo http )}"
HOST="${HC_HOST:-127.0.0.1}"
PORT_DEFAULT="$( [ "$USE_SSL" = "1" ] && echo 443 || echo 80 )"
PORT="${HC_PORT:-$PORT_DEFAULT}"

# Accept self-signed certs by default for internal probe
CURL_INSECURE_FLAG=""
[ "$SCHEME" = "https" ] && [ "${HC_INSECURE:-1}" = "1" ] && CURL_INSECURE_FLAG="-k"

# Determine MRTG interval
INTERVAL_MIN="$(awk 'tolower($1)=="interval:"{print $2; exit}' /etc/mrtg.cfg 2>/dev/null || true)"
if [ -z "${INTERVAL_MIN}" ]; then
  PI="${POLL_INTERVAL:-300}"; case "$PI" in ''|*[!0-9]*) PI=300;; esac
  INTERVAL_MIN=$((PI / 60)); [ "$INTERVAL_MIN" -lt 1 ] && INTERVAL_MIN=1
fi
INTERVAL_SEC=$((INTERVAL_MIN * 60))

# Warm-up window (seconds)
WARMUP_SEC="${HC_WARMUP_SEC:-$((INTERVAL_SEC * 2 + 60))}"
UP="$(cut -d'.' -f1 </proc/uptime 2>/dev/null || echo 0)"

# 1) Webserver presence: TCP connect (no HTTP)
if [ "${RUN_WEBSERVER:-1}" = "1" ]; then
  if nc -h 2>&1 | grep -q ' -z '; then
    nc -z -w 2 "$HOST" "$PORT" || { echo "health: TCP connect to $HOST:$PORT failed"; exit 1; }
  else
    # Fallback: send empty payload with timeout
    echo | nc -w 2 "$HOST" "$PORT" >/dev/null 2>&1 || { echo "health: TCP connect to $HOST:$PORT failed"; exit 1; }
  fi
  # Optional HTTP(S) check if curl is available and not disabled
  if command -v curl >/dev/null 2>&1 && [ "${HC_TCP_ONLY:-0}" != "1" ]; then
    curl -fsS -m 3 $CURL_INSECURE_FLAG "${SCHEME}://${HOST}:${PORT}/" >/dev/null \
      || { echo "health: HTTP check failed on ${SCHEME}://${HOST}:${PORT}/"; exit 1; }
  fi
fi

# 2) During warm-up, skip RRD strictness so pod becomes Ready
if [ "$UP" -lt "$WARMUP_SEC" ]; then
  echo "healthy (warmup): up=${UP}s < ${WARMUP_SEC}s"
  exit 0
fi

# 3) RRD exists and is fresh
[ -f "$RRD" ] || { echo "health: missing RRD: $RRD"; exit 1; }
LASTLINE="$(rrdtool lastupdate "$RRD" 2>/dev/null | tail -n 1 || true)"
TS="${LASTLINE%%:*}"
case "$TS" in ''|*[!0-9]*) echo "health: invalid lastupdate: $LASTLINE"; exit 1;; esac
NOW="$(date +%s)"; AGE=$((NOW - TS))
MAX_AGE="${HC_MAX_AGE_SEC:-$((INTERVAL_SEC * 2 + 60))}"
[ "$AGE" -le "$MAX_AGE" ] || { echo "health: stale RRD (age=${AGE}s > ${MAX_AGE}s)"; exit 1; }

# 4) rrdtool graph smoke test (fonts/options sanity)
if ! rrdtool graph /tmp/health.png -s -1h -e now \
  DEF:in="$RRD":ds0:AVERAGE LINE1:in#00ff00:In \
  --border 0 \
  -c FONT#e0e0e0 -c AXIS#aaaaaa -c FRAME#888888 \
  -c GRID#444444 -c MGRID#666666 -c BACK#202020 -c CANVAS#282828 \
  >/dev/null 2>&1; then
  echo "health: rrdtool graph failed"; exit 1
fi
rm -f /tmp/health.png 2>/dev/null || true

# 5) Optional CGI check
if [ "${RUN_WEBSERVER:-1}" = "1" ] && [ "${HC_CHECK_CGI:-1}" = "1" ] && command -v curl >/dev/null 2>&1; then
  curl -fsS -m 5 $CURL_INSECURE_FLAG \
    "${SCHEME}://${HOST}:${PORT}/cgi-bin/14all.cgi?log=${TARGET}&png=day.s&small=1" \
    -o /dev/null || { echo "health: 14all.cgi not reachable"; exit 1; }
fi

echo "healthy: age=${AGE}s interval=${INTERVAL_MIN}m scheme=${SCHEME} port=${PORT}"