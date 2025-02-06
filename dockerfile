# Base Image
FROM alpine:latest

# Set Environment Variable defaults
ENV PATH=/usr/local/nginx/bin:$PATH
ENV TZ=Europe/Berlin
ENV DEBUG=0
ENV RUN_WEBSERVER=1
ENV USE_DARKMODE=1
ENV POLL_INTERVAL=300
ENV MAX_DOWNLOAD_BYTES=12500000
ENV MAX_UPLOAD_BYTES=5000000
ENV FRITZBOX_MODEL=7590
ENV FRITZBOX_IP=192.168.1.1

# Install additional Packages
RUN apk add --update --no-cache \
  bash \
  mrtg \
  nginx \
  tzdata

# Copy our files to the Container
COPY ./fritzbox-mrtg/entrypoint.sh /
COPY ./fritzbox-mrtg/mrtg.cfg /fritzbox-mrtg/
COPY ./fritzbox-mrtg/upnp2mrtg.sh /fritzbox-mrtg/
COPY ./fritzbox-mrtg/style.css /fritzbox-mrtg/htdocs/
COPY ./fritzbox-mrtg/style_light.css /fritzbox-mrtg/htdocs/
COPY ./fritzbox-mrtg/mrtg-l.png /fritzbox-mrtg/htdocs/icons/
COPY ./fritzbox-mrtg/mrtg-m.png /fritzbox-mrtg/htdocs/icons/
COPY ./fritzbox-mrtg/mrtg-r.png /fritzbox-mrtg/htdocs/icons/
COPY ./fritzbox-mrtg/default.conf /etc/nginx/http.d/
COPY ./fritzbox-mrtg/nginx.conf /etc/nginx/

# Fix Windows linebreaks
RUN sed -i -e 's/\r$//' /entrypoint.sh
RUN sed -i -e 's/\r$//' /fritzbox-mrtg/upnp2mrtg.sh
RUN sed -i -e 's/\r$//' /fritzbox-mrtg/mrtg.cfg
RUN sed -i -e 's/\r$//' /etc/nginx/http.d/default.conf
RUN sed -i -e 's/\r$//' /etc/nginx/nginx.conf
RUN sed -i -e 's/\r$//' /fritzbox-mrtg/htdocs/style.css
RUN sed -i -e 's/\r$//' /fritzbox-mrtg/htdocs/style_light.css

# Fix permission errors
RUN chmod +x /entrypoint.sh
RUN chmod +x /fritzbox-mrtg/entrypoint.sh

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Ports & Volumes
EXPOSE 80
VOLUME ["/srv/www/htdocs"]

# Default parameter to run
CMD [""]