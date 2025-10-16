#!/bin/sh
# upnp2mrtg - Monitoring AVM Fritz!Box With MRTG (sh-compatible)
# Original copyright (C) 2005-2008 Michael Tomschitz
# GPLv2 or later

HOST="${HOST:-192.168.1.1}"
PORT="49000"
NETCAT="netcat"

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
  echo "$((${1} / ${2})) $((${1} % ${2}))"
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
  _get_response_rs="$(echo "$1" | run_with_timeout 5 $nc_cmd "$HOST" "$PORT" 2>/dev/null)"
  _get_response_rv=$?
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
  request="`soap_form "$1" WANCommonInterfaceConfig`"
  post="`request_header "$HOST" "$PORT" "${#request}" WANCommonIFC1 WANCommonInterfaceConfig "$1"`

$request"
  rs="`get_response "$post"`"
  if [ $? -eq 0 ]; then
    echo "`get_attribute "$2" "$rs"`"
  fi
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
    # get uptime
    request="`soap_form GetStatusInfo WANIPConnection`"
    post="`request_header "$HOST" "$PORT" "${#request}" WANIPConn1 WANIPConnection GetStatusInfo`

$request"
    rs="`get_response "$post"`"
    if [ $? -eq 0 ]; then
      ut=`get_attribute NewUptime "$rs"`
      s=`modulo_time ${ut:-0} 60`
      m=`modulo_time ${s% *} 60`
      h=`modulo_time ${m% *} 24`
    fi

    # get data in/out
    if ${PACKET_MODE:-false}; then
      b1="`ws_operation GetTotalPacketsReceived NewTotalPacketsReceived`"
      b2="`ws_operation GetTotalPacketsSent NewTotalPacketsSent`"
    else
      b1="`ws_operation GetAddonInfos NewTotalBytesReceived`"
      b2="`ws_operation GetAddonInfos NewTotalBytesSent`"
    fi

    # output for mrtg (use U for unknown)
    printf "%s\n%s\n%d days %.2d:%.2d:%.2d h (online)\nFRITZ!Box\n" \
      "${b1:-U}" "${b2:-U}" "${h% *}" "${h#* }" "${m#* }" "${s#* }"
    ;;
esac