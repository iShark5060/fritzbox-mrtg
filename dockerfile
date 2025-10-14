# Base Image
FROM alpine:latest

LABEL author="Lutz Schwemer Panchez"
LABEL description="Simple, lightweight script that uses upnp2mrtg to \
communicate with your Fritz!Box and collect bandwidth data. It's then sent \
to mrtg for pretty graphs and finally displayed to a simple website using \
nginx."
LABEL version="1.2"

LABEL org.opencontainers.image.source=https://github.com/ishark5060/fritzbox-mrtg
LABEL org.opencontainers.image.description="Simple, lightweight script that \
uses upnp2mrtg to communicate with your Fritz!Box and collect bandwidth \
data. It's then sent to mrtg for pretty graphs and finally displayed to a \
simple website using nginx."
LABEL org.opencontainers.image.licenses=MIT

# Set Environment Variable defaults
ENV TZ=Europe/Berlin
ENV DEBUG=0
ENV RUN_WEBSERVER=1
ENV USE_DARKMODE=1
ENV POLL_INTERVAL=300
ENV MAX_DOWNLOAD_BYTES=12500000
ENV MAX_UPLOAD_BYTES=5000000
ENV FRITZBOX_MODEL=7590
ENV FRITZBOX_IP=192.168.1.1
ENV USE_SSL=0

# Install packages
RUN apk add --no-cache \
  nginx \
  mrtg \
  perl \
  perl-cgi \
  rrdtool \
  perl-rrd \
  fcgiwrap \
  spawn-fcgi \
  curl \
  tzdata \
  ca-certificates \
  gettext \
  netcat-openbsd \
  bash \
  fontconfig \
  ttf-dejavu

# Copy our files to the Container
COPY ./fritzbox-mrtg/entrypoint.sh /
COPY ./fritzbox-mrtg/mrtg.cfg.tmpl /fritzbox-mrtg/
COPY ./fritzbox-mrtg/upnp2mrtg.sh /fritzbox-mrtg/
COPY ./fritzbox-mrtg/style.css /fritzbox-mrtg/htdocs/
COPY ./fritzbox-mrtg/style_light.css /fritzbox-mrtg/htdocs/
COPY ./fritzbox-mrtg/mrtg-l.png /fritzbox-mrtg/htdocs/icons/
COPY ./fritzbox-mrtg/mrtg-m.png /fritzbox-mrtg/htdocs/icons/
COPY ./fritzbox-mrtg/mrtg-r.png /fritzbox-mrtg/htdocs/icons/
COPY ./fritzbox-mrtg/mrtg-l.gif /fritzbox-mrtg/htdocs/icons/
COPY ./fritzbox-mrtg/mrtg-m.gif /fritzbox-mrtg/htdocs/icons/
COPY ./fritzbox-mrtg/mrtg-r.gif /fritzbox-mrtg/htdocs/icons/
COPY ./fritzbox-mrtg/default.conf /fritzbox-mrtg/
COPY ./fritzbox-mrtg/default_ssl.conf /fritzbox-mrtg/
COPY ./fritzbox-mrtg/nginx.conf /etc/nginx/
COPY ./fritzbox-mrtg/cgi-bin/14all.cgi /srv/www/cgi-bin/14all.cgi

# Fix Windows linebreaks
RUN sed -i -e 's/\r$//' /entrypoint.sh \
  -e 's/\r$//' /fritzbox-mrtg/upnp2mrtg.sh \
  -e 's/\r$//' /fritzbox-mrtg/mrtg.cfg.tmpl \
  -e 's/\r$//' /fritzbox-mrtg/default.conf \
  -e 's/\r$//' /fritzbox-mrtg/default_ssl.conf \
  -e 's/\r$//' /etc/nginx/nginx.conf \
  -e 's/\r$//' /fritzbox-mrtg/htdocs/style.css \
  -e 's/\r$//' /fritzbox-mrtg/htdocs/style_light.css

# Fix permission errors
RUN chmod +x /entrypoint.sh /fritzbox-mrtg/upnp2mrtg.sh
RUN chmod 0755 /srv/www/cgi-bin/14all.cgi

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Ports & Volumes
EXPOSE 80 443
VOLUME ["/srv/www/htdocs"]

SHELL ["/bin/sh", "-c"]

# Default parameter to run
CMD [""]