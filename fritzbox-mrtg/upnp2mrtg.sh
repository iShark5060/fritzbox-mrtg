#!/bin/sh
# upnp2mrtg - Monitoring AVM Fritz!Box With MRTG (sh-compatible)
# Original copyright (C) 2005-2008 Michael Tomschitz
# GPLv2 or later

HOST="${HOST:-192.168.1.1}"
PORT="49000"
NETCAT="netcat"

LAST_STATUS_CODE=""
LAST_STATUS_TEXT=""
LAST_ERROR_MESSAGE=""

# if available, read configuration
[ -f /etc/upnp2mrtg.cfg ] && . /etc/upnp2mrtg.cfg

case "$NETCAT" in
  bash) nc="shell_netcat" ;;
  netcat) nc="netcat" ;;
  nc_q) nc="nc -q 1" ;;
  *) nc="nc" ;;
esac

ver_txt="upnp2mrtg, version 1.9
Copyright (C) 2005-2008 Michael Tomschitz
upnp2mrtg comes with ABSOLUTELY NO WARRANTY. This is free software,
and you are welcome to redistribute it under certain conditions."

help_txt="\
Usage: upnp2mrtg [-a <host>] [-p <port>] [-P] [-d] [-h] [-i] [-t] [-v] [-V]

  -a <host>    hostname or ip adress of upnp device (default: $HOST)
  -p <port>    port to connect (default: $PORT)
  -P           query packets instead of bytes
  -d           debug mode
  -h           show help and exit
  -i <outfile> get all igd description
  -t           test connection
  -v           show upnp2mrtg version and exit
  -V           be verbose for testing
"

log_error() {
  printf '%s %s\n' "$(date -Is 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')" "$*" >&2
}

while getopts "a:dhi:p:PtvV" option; do
  case "$option" in
    a) HOST="$OPTARG" ;;
    d) set -x ;;
    h) echo "$help_txt"; exit 0 ;;
    i) MODE=igd; IGDXML="$OPTARG" ;;
    p) PORT="$OPTARG" ;;
    P) PACKET_MODE=true ;;
    t) MODE="test" ;;
    v) echo "$ver_txt"; exit 0 ;;
    V) VERBOSE=true ;;
    ?) exit 1 ;;
  esac
done

request_header() {
cat <<EOF
POST /igdupnp/control/$4 HTTP/1.0
HOST: $1:$2
CONTENT-LENGTH: $3
CONTENT-TYPE: text/xml; charset="utf-8"
SOAPACTION: "urn:schemas-upnp-org:service:$5:1#$6"
Connection: close
EOF
}

soap_form() {
cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope
        xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
        s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <s:Body>
        <u:$1 xmlns:u="urn:schemas-upnp-org:service:$2:1" />
    </s:Body>
</s:Envelope>
EOF
}

get_attribute() {
  _get_attribute_start_tag() { echo "${2#*<$1>*}"; }
  _get_attribute_end_tag() { echo "${2%*</$1>*}"; }
  _get_attribute_tag() { _get_attribute_start_tag "$1" "`_get_attribute_end_tag "$1" "$2"`"; }
  _get_attribute_num() { echo $#; }
  if [ "`_get_attribute_num "$1"`" -gt 1 ]; then
    get_attribute "${1#* }" "`_get_attribute_tag "${1%% *}" "$2"`"
  else
    _get_attribute_tag "$1" "$2"
  fi
}

modulo_time() {
  local val="${1:-0}"
  local mod="${2:-1}"
  # Ensure values are numeric, default to 0 if not
  case "$val" in
    ''|*[!0-9]*) val=0 ;;
  esac
  case "$mod" in
    ''|*[!0-9]*|0) mod=1 ;;
  esac
  echo "$((${val} / ${mod})) $((${val} % ${mod}))"
}

shell_netcat() {
  # Only used if NETCAT=bash; /dev/tcp not available in sh/ash.
  exec 5<>/dev/tcp/"$1"/"$2"; cat >&5; cat <&5
}

# Cross-platform timeout wrapper (GNU coreutils, BusyBox, or none)
run_with_timeout() {
  if timeout 0.1s true >/dev/null 2>&1; then
    timeout "$@"; return $?
  fi
  if timeout 1 true >/dev/null 2>&1; then
    _t="$1"; shift
    _t="${_t%s}"
    timeout "$_t" "$@"; return $?
  fi
  if timeout -t 1 true >/dev/null 2>&1; then
    _t="$1"; shift
    _t="${_t%s}"
    timeout -t "$_t" "$@"; return $?
  fi
  "$@"
}

# Prefer -N with netcat-openbsd if available (closes after stdin EOF)
nc_cmd="$nc"
$nc -h 2>&1 | grep -q ' -N ' && nc_cmd="$nc -N"

get_response() {
  LAST_STATUS_CODE=""
  LAST_STATUS_TEXT=""
  LAST_ERROR_MESSAGE=""

  _get_response_rs="$(echo "$1" | run_with_timeout 5 $nc_cmd "$HOST" "$PORT" 2>/dev/null)"
  _get_response_rv=$?

  status_line="$(printf '%s\n' "$_get_response_rs" | head -n1)"
  case "$status_line" in
    HTTP/*)
      LAST_STATUS_TEXT="$status_line"
      LAST_STATUS_CODE="$(printf '%s' "$status_line" | awk '{print $2}')"
      ;;
    *)
      LAST_STATUS_TEXT=""
      LAST_STATUS_CODE=""
      ;;
  esac

  if [ $_get_response_rv -ne 0 ]; then
    LAST_ERROR_MESSAGE="netcat failed with exit $_get_response_rv"
  else
    case "$LAST_STATUS_CODE" in
      ''|*[!0-9]*) ;;
      *)
        if [ "$LAST_STATUS_CODE" -ge 400 ] 2>/dev/null; then
          LAST_ERROR_MESSAGE="HTTP error ${LAST_STATUS_CODE}"
        fi
        ;;
    esac
  fi

  echo "$_get_response_rs"
  if ${VERBOSE:-false}; then
    echo
    echo "---- REQUEST: ----" >&2
    echo "$1" >&2
    echo "---- RESPONSE: ----" >&2
    echo "$_get_response_rs" >&2
    echo "----" >&2
  fi
  return $_get_response_rv
}

request_header_http() {
cat <<EOF
GET $3 HTTP/1.0
Connection: close

EOF
}

ws_operation() {
  request=$(soap_form "$1" WANCommonInterfaceConfig)
  header=$(request_header "$HOST" "$PORT" "${#request}" WANCommonIFC1 WANCommonInterfaceConfig "$1")
  post=$(printf '%s\n%s' "$header" "$request")
  rs=$(get_response "$post")
  grc=$?
  if [ $grc -ne 0 ]; then
    log_error "upnp2mrtg: request '$1' failed (${LAST_ERROR_MESSAGE:-exit $grc})"
    return $grc
  fi

  case "$LAST_STATUS_CODE" in
    ''|*[!0-9]*) ;;
    *)
      if [ "$LAST_STATUS_CODE" -ge 400 ] 2>/dev/null; then
        log_error "upnp2mrtg: HTTP ${LAST_STATUS_CODE} for action '$1'"
        return 1
      fi
      ;;
  esac

  value=$(get_attribute "$2" "$rs")
  if [ -z "$value" ]; then
    log_error "upnp2mrtg: missing attribute '$2' in response to '$1' (status ${LAST_STATUS_CODE:-unknown})"
    return 1
  fi

  printf '%s\n' "$value"
  return 0
}

case "$MODE" in
  test)
    echo "GET /any.xml HTTP/1.0
" | $nc_cmd "$HOST" "$PORT" >/dev/null
    [ $? -eq 0 ] && { echo "OK"; exit 0; } || { echo "Connection Error"; exit 1; }
    ;;
  igd)
    if [ -f "$IGDXML" ]; then
      echo "ERROR: $IGDXML: File exists." >&2; exit 1
    fi
    for igd in any igdconnSCPD igddesc igddslSCPD igdicfgSCPD; do
      request="`request_header_http "$HOST" "$PORT" "/$igd.xml"`"
      rs="`get_response "$request"`"
      if [ "$IGDXML" = "-" ]; then
        echo "---- $igd.xml ----
$rs"
      else
        echo "---- $igd.xml ----
$rs" >> "$IGDXML"
      fi
    done
    ;;
  *)
    # Initialize variables
    h="0 0"
    m="0 0"
    s="0 0"
    
    # get uptime
    request="`soap_form GetStatusInfo WANIPConnection`"
    header="`request_header "$HOST" "$PORT" "${#request}" WANIPConn1 WANIPConnection GetStatusInfo`"
    post=$(printf '%s\n%s' "$header" "$request")
    rs=$(get_response "$post")
    grc=$?
    if [ $grc -ne 0 ]; then
      log_error "upnp2mrtg: GetStatusInfo failed (${LAST_ERROR_MESSAGE:-exit $grc})"
    else
      case "$LAST_STATUS_CODE" in
        ''|*[!0-9]*) ;;
        *)
          if [ "$LAST_STATUS_CODE" -ge 400 ] 2>/dev/null; then
            log_error "upnp2mrtg: HTTP ${LAST_STATUS_CODE} for GetStatusInfo"
          else
            ut=$(get_attribute NewUptime "$rs")
            if [ -n "$ut" ] && [ "$ut" != "U" ]; then
              ut="${ut:-0}"
              s=$(modulo_time "$ut" 60)
              s_first="${s% *}"
              s_first="${s_first:-0}"
              m=$(modulo_time "$s_first" 60)
              m_first="${m% *}"
              m_first="${m_first:-0}"
              h=$(modulo_time "$m_first" 24)
            else
              log_error "upnp2mrtg: missing uptime data in response"
            fi
          fi
          ;;
      esac
    fi

    # get data in/out
    if [ "${PACKET_MODE:-false}" = "true" ]; then
      b1=$(ws_operation GetTotalPacketsReceived NewTotalPacketsReceived) || {
        log_error "upnp2mrtg: failed to fetch total packets received"; b1="U";
      }
      b2=$(ws_operation GetTotalPacketsSent NewTotalPacketsSent) || {
        log_error "upnp2mrtg: failed to fetch total packets sent"; b2="U";
      }
    else
      b1=$(ws_operation GetAddonInfos NewTotalBytesReceived) || {
        log_error "upnp2mrtg: failed to fetch total bytes received"; b1="U";
      }
      b2=$(ws_operation GetAddonInfos NewTotalBytesSent) || {
        log_error "upnp2mrtg: failed to fetch total bytes sent"; b2="U";
      }
    fi

    # output for mrtg (use U for unknown)
    printf "%s\n%s\n%d days %.2d:%.2d:%.2d h (online)\nFRITZ!Box\n" \
      "${b1:-U}" "${b2:-U}" "${h% *}" "${h#* }" "${m#* }" "${s#* }"
    ;;
esac