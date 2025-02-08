#!/bin/sh

[ "${DEBUG}" = "1" ] && set -x

export PATH=/usr/sbin:/sbin:${PATH}
export LANG=C

RUN_WEBSERVER=${RUN_WEBSERVER:-1}
USE_DARKMODE=${USE_DARKMODE:-1}
POLL_INTERVAL=${POLL_INTERVAL:-300}
MAX_DOWNLOAD_BYTES=${MAX_DOWNLOAD_BYTES:-12500000}
MAX_UPLOAD_BYTES=${MAX_UPLOAD_BYTES:-5000000}
FRITZBOX_MODEL=${FRITZBOX_MODEL:-7590}
FRITZBOX_IP=${FRITZBOX_IP:-192.168.1.1}

setup_timezone() {
    if [ -n "$TZ" ]; then
		TZ_FILE="/usr/share/zoneinfo/$TZ"
		if [ -f "$TZ_FILE" ]; then
			echo "Setting container timezone to: $TZ"
			ln -snf "$TZ_FILE" /etc/localtime
		else
			echo "Cannot set timezone \"$TZ\": timezone does not exist."
		fi
    fi
}

# Stop NGINX Webserver
stop_nginx() {
    rv=$?
    [ "${RUN_WEBSERVER}" = "1" ] && nginx -s quit
    exit $rv
}
init_trap() {
    trap stop_nginx TERM INT EXIT
}

# Generic setup
setup_timezone
init_trap

# Remove old config files
if [ -f /etc/mrtg.cfg ]; then
	rm /etc/mrtg.cfg
fi
if [ -f /etc/upnp2mrtg.cfg ]; then
	rm /etc/upnp2mrtg.cfg
fi

# Copy style files and icons, if missing
if [ ! -f /srv/www/htdocs/style.css ] || [ ! -f /srv/www/htdocs/icons/mrtg-l.png ]; then
	cp -r /fritzbox-mrtg/htdocs/* /srv/www/htdocs/
fi

# Calculate variables
DL_KBITS=$((${MAX_DOWNLOAD_BYTES}*8/1000))
UL_KBITS=$((${MAX_UPLOAD_BYTES}*8/1000))

# Darkmode?
if [ "${USE_DARKMODE}" = "0" ]; then
	CSS="style_light.css"
else
	CSS="style.css"
fi

# Replace variables in mrtg config file and copy it to the right place
if [ ! -f /etc/mrtg.cfg ]; then
	sed -e "s|7590|${FRITZBOX_MODEL}|g" \
	-e "s|172.16.0.1|${FRITZBOX_IP}|g" \
	-e "s|^MaxBytes1\[fritzbox\]:.*|MaxBytes1\[fritzbox\]: ${MAX_DOWNLOAD_BYTES}|g" \
	-e "s|250.000|${DL_KBITS}|g" \
	-e "s|^MaxBytes2\[fritzbox\]:.*|MaxBytes2\[fritzbox\]: ${MAX_UPLOAD_BYTES}|g" \
	-e "s|40.000|${UL_KBITS}|g" \
	-e "s|^AddHead\[fritzbox\]:.*|AddHead\[fritzbox\]: <link rel=\"stylesheet\" type=\"text/css\" href=\"${CSS}\">|g" \
	/fritzbox-mrtg/mrtg.cfg > /etc/mrtg.cfg
fi

# Create new upnp2mrtg config file
if [ ! -f /etc/upnp2mrtg.cfg ]; then
	echo "HOST=\"${FRITZBOX_IP}\"" > /etc/upnp2mrtg.cfg
	echo "NETCAT=\"nc\"" >> /etc/upnp2mrtg.cfg
fi

# Restart NGINX server
[ "${RUN_WEBSERVER}" = "1" ] && nginx

# Loop to pull new data
while true; do
  DATE=$(date -Iseconds)
  echo "$DATE Fetch new data"
  /usr/bin/mrtg /etc/mrtg.cfg
  sleep "${POLL_INTERVAL}"
done
