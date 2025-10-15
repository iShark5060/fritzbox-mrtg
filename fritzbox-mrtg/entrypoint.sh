#!/bin/sh
set -Eeuo pipefail
[ "${DEBUG:-0}" = "1" ] && set -x

export PATH=/usr/sbin:/sbin:${PATH}
export LANG=C

RUN_WEBSERVER=${RUN_WEBSERVER:-1}
USE_DARKMODE=${USE_DARKMODE:-1}
POLL_INTERVAL=${POLL_INTERVAL:-300}
MAX_DOWNLOAD_BYTES=${MAX_DOWNLOAD_BYTES:-12500000}
MAX_UPLOAD_BYTES=${MAX_UPLOAD_BYTES:-5000000}
FRITZBOX_MODEL=${FRITZBOX_MODEL:-7590}
FRITZBOX_IP=${FRITZBOX_IP:-192.168.1.1}
USE_SSL=${USE_SSL:-0}

INTERVAL_MIN=$((POLL_INTERVAL / 60))

log() {
  printf "%s %s\n" "$(date -Is)" "$*"
}

setup_timezone() {
  if [ -n "${TZ:-}" ]; then
    TZ_FILE="/usr/share/zoneinfo/$TZ"
    if [ -f "$TZ_FILE" ]; then
      ln -snf "$TZ_FILE" /etc/localtime
      echo "$TZ" >/etc/timezone || true
      log "Timezone set to: $TZ"
    else
      log "Cannot set timezone \"$TZ\": timezone not found"
    fi
  fi
}

cleanup() {
  rv=$?
  if [ "${RUN_WEBSERVER}" = "1" ] && pidof nginx >/dev/null 2>&1; then
    nginx -s quit || true
  fi
  exit $rv
}
trap cleanup TERM INT EXIT

# Cross-platform timeout wrapper for commands
run_with_timeout() {
  if timeout 0.1s true >/dev/null 2>&1; then
    timeout "$@"; return $?
  fi
  if timeout 1 true >/dev/null 2>&1; then
    local first="$1"; shift
    first="${first%s}"
    timeout "$first" "$@"; return $?
  fi
  if timeout -t 1 true >/dev/null 2>&1; then
    local first="$1"; shift
    first="${first%s}"
    timeout -t "$first" "$@"; return $?
  fi
  "$@"
}

setup_timezone

mkdir -p /run/nginx /etc/nginx/http.d
mkdir -p /srv/www/htdocs/icons
if [ ! -f /srv/www/htdocs/style.css ] || \
   [ ! -f /srv/www/htdocs/icons/mrtg-l.png ]; then
  cp -r /fritzbox-mrtg/htdocs/* /srv/www/htdocs/
fi

if [ "${USE_SSL}" = "1" ]; then
  cp /fritzbox-mrtg/default_ssl.conf /etc/nginx/http.d/default.conf
else
  cp /fritzbox-mrtg/default.conf /etc/nginx/http.d/default.conf
fi

DL_KBITS=$((MAX_DOWNLOAD_BYTES * 8 / 1000))
UL_KBITS=$((MAX_UPLOAD_BYTES * 8 / 1000))

if [ "${USE_DARKMODE}" = "1" ]; then
  CSS="style.css"
  COL_IN="GREEN#00eb0c"
  COL_OUT="BLUE#10a0ff"
  COL_MAXIN="DARK GREEN#006600"
  COL_MAXOUT="VIOLET#ff70ff"

  PAGE_BG="#1e1e1e"
  GRID_COLOR="#444444"
  MGRID_COLOR="#666666"
  BACK_COLOR="#202020"
  CANVAS_COLOR="#282828"
  FONT_COLOR="#e0e0e0"
  AXIS_COLOR="#aaaaaa"
  FRAME_COLOR="#888888"
else
  CSS="style_light.css"
  COL_IN="GREEN#00a50c"
  COL_OUT="BLUE#0060ff"
  COL_MAXIN="DARK GREEN#006600"
  COL_MAXOUT="VIOLET#aa00aa"

  PAGE_BG="#ffffff"
  GRID_COLOR="#cccccc"
  MGRID_COLOR="#999999"
  BACK_COLOR="#ffffff"
  CANVAS_COLOR="#f7f7f7"
  FONT_COLOR="#202020"
  AXIS_COLOR="#666666"
  FRAME_COLOR="#888888"
fi

export COL_IN COL_OUT COL_MAXIN COL_MAXOUT
export FONT_COLOR AXIS_COLOR FRAME_COLOR
export PAGE_BG GRID_COLOR MGRID_COLOR BACK_COLOR CANVAS_COLOR

if [ ! -f /etc/mrtg.cfg ]; then
  export FRITZBOX_MODEL FRITZBOX_IP MAX_DOWNLOAD_BYTES MAX_UPLOAD_BYTES
  export DL_KBITS UL_KBITS CSS INTERVAL_MIN
  export COL_IN COL_OUT COL_MAXIN COL_MAXOUT
  export PAGE_BG GRID_COLOR MGRID_COLOR BACK_COLOR CANVAS_COLOR
	export FONT_COLOR AXIS_COLOR FRAME_COLOR

  envsubst '
    ${FRITZBOX_MODEL}
    ${FRITZBOX_IP}
    ${MAX_DOWNLOAD_BYTES}
    ${MAX_UPLOAD_BYTES}
    ${DL_KBITS}
    ${UL_KBITS}
    ${CSS}
    ${INTERVAL_MIN}
    ${COL_IN}
    ${COL_OUT}
    ${COL_MAXIN}
    ${COL_MAXOUT}
    ${PAGE_BG}
    ${GRID_COLOR}
    ${MGRID_COLOR}
    ${BACK_COLOR}
    ${CANVAS_COLOR}
    ${FONT_COLOR}
    ${AXIS_COLOR}
    ${FRAME_COLOR}
  ' < /fritzbox-mrtg/mrtg.cfg.tmpl > /etc/mrtg.cfg
fi

printf 'HOST="%s"\nNETCAT="nc"\n' "${FRITZBOX_IP}" > /etc/upnp2mrtg.cfg

mkdir -p /run
spawn-fcgi -s /run/fcgiwrap.sock -M 766 -u nginx -g nginx /usr/bin/fcgiwrap

if [ "${RUN_WEBSERVER}" = "1" ]; then
  nginx
fi

if [ ! -f /srv/www/htdocs/index.html ]; then
  indexmaker --rrdviewer='/cgi-bin/14all.cgi' /etc/mrtg.cfg > /srv/www/htdocs/index.html || true
	sed -i 's#</HEAD>#  <link rel="stylesheet" type="text/css" href="/'${CSS}'">\n</HEAD>#' /srv/www/htdocs/index.html
fi

while true; do
  log "Fetch new data"
  run_with_timeout 15 /usr/bin/mrtg /etc/mrtg.cfg || log "mrtg run failed"
  sleep "${POLL_INTERVAL}"
done