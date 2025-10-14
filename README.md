# Monitor your FRITZ!Box

![Static Badge](https://img.shields.io/badge/Debian-stable--slim-red?style=for-the-badge) ![Debian package](https://img.shields.io/debian/v/busybox?style=for-the-badge&label=BusyBox&color=teal) ![Debian package](https://img.shields.io/debian/v/mrtg?style=for-the-badge&label=MRTG) ![Debian package](https://img.shields.io/debian/v/nginx?style=for-the-badge&label=NGINX&color=green)

Simple, lightweight script that uses `upnp2mrtg` to communicate with your
Fritz!Box and collect bandwidth data. It's then sent to `mrtg` for pretty
graphs and finally displayed to a simple website using `nginx`.

The whole project is based on the work of [Thorsten Kukuk](https://github.com/thkukuk/fritzbox-monitoring/)

## About

This is my first self-built docker container. Initially I wanted to use the Alpine base image, but for some reason the output to the `fritzbox.log` file would be corrupted (the script didn't output the 0 values), so I swapped over to Ubuntu as I was way more familiar with it. After getting everything working, I swapped to Debian because the image is appx. 200MB smaller without compromising any functionality (for this project).

The script itself is more or less a direct copy from [Thorsten Kukuk](https://github.com/thkukuk/fritzbox-monitoring/) with some additions from me.

## Requirements

- Docker, Podman or some other way of running the container
- Fritz!Box with UPNP enabled (Home Network -> Network -> Transmit status information over UPnP)

## Running the Container

Docker compose (recommended):
```
services:
  fritzbox-mrtg:
    image: shark5060/fritzbox-mrtg:latest
    container_name: fritzbox-mrtg
    environment:
      - TZ=Europe/Berlin
      - DEBUG=0
      - RUN_WEBSERVER=1
      - USE_DARKMODE=1
      - POLL_INTERVAL=300
      - MAX_DOWNLOAD_BYTES=12500000
      - MAX_UPLOAD_BYTES=5000000
      - FRITZBOX_MODEL=7590
      - FRITZBOX_IP=192.168.1.1
    volumes:
      - /path/to/config:/srv/www/htdocs
    ports:
      - 3000:80
    restart: unless-stopped
```

Docker run:
```
docker run -d \
  --name=fritzbox-mrtg \
  -e TZ=Europe/Berlin \
  -e DEBUG=0 \
  -e RUN_WEBSERVER=1 \
  -e USE_DARKMODE=1 \
  -e POLL_INTERVAL=300 \
  -e MAX_DOWNLOAD_BYTES=12500000 \
  -e MAX_UPLOAD_BYTES=5000000 \
  -e FRITZBOX_MODEL=7590 \
  -e FRITZBOX_IP=192.168.1.1 \
  -p 3000:80 \
  -v /path/to/config:/srv/www/htdocs \
  --restart unless-stopped \
  shark5060/fritzbox-mrtg:latest
```

## Environment Variables

All binary variables use either `1` or `0` as value.

| Variable | Description | Default |
| ------------- | ------------- | ------------- |
| DEBUG  | Run entrypoint script in debug mode. | `0` |
| TZ  | Set a timezone the container should use. <br>Use [this Wikipedia List](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) for Values. | `Europe/Berlin` |
| POLL_INTERVAL  | Polling interval in seconds. | `300` |
| RUN_WEBSERVER  | Run NGINX Webserver to display output. | `1` |
| USE_DARKMODE  | Set to `1` if you want to use the Darkmode CSS values. | `1` |
| MAX_DOWNLOAD_BYTES  | Max. incoming traffic in Bytes per Second. | `12500000` |
| MAX_UPLOAD_BYTES  | Max. outgoing traffic in Bytes per Second. | `5000000` |
| FRITZBOX_MODEL  | Model of the Fritz!Box being monitored. | `7590` |
| FRITZBOX_IP  | IP address of the Fritz!Box being monitored. <br>Container needs to be able to reach this IP. | `192.168.1.1` |
| USE_SSL  | Set to `1` to use SSL certificate and run an HTTPS server instead of an HTTP server. Port changes from :80 to :443 as well. See below. | `0` |

## SSL Certificate

To use an SSL certificate and run an HTTPS server instead of an HTTP one, you have to have a valid SSL certificate already.
NGINX will run on Port 443 instead of 80 internally, so you need to change the binding as well as provide a path for the SSL certificate.

1) Mount the directory `/etc/nginx/ssl/` to one containing the SSL certificate (named `cert.pem`) and the Private Key (named `cert.key`).
```
volumes:
      - /path/to/ssl/cert:/etc/nginx/ssl/
```
2) Set the `USE_SSL` environment variable to `1`.
3) Change the Port config from `3000:80` to `3000:443` (or use whatever host port you'd like obviously).
4) Access the container via `https://your.domain.tld:3000/fritzbox.html`.

## Volumes:

`/path/to/config:/srv/www/htdocs`
Output directory for both the historical data (stored in `fritzbox.log`) as well as the generated images/website.
Point this to a directory writeable by the docker user or the user set in the compose/run command.
If unset, data will not be persistent.

`/path/to/ssl/cert:/etc/nginx/ssl/`
Optional directory for using an SSL certificate. Please see the section about SSL Certificate in the readme.

## Output

To view the generated website, visit `http://your.dockerhost.ip:3000/fritzbox.html`.
If you're using SSL, the website is located at `https://your.domain.tld:3000/fritzbox.html`.

## Make it pretty

You can edit the default `style.css` located in the output directory to control how the website looks.
If you messed up, delete the `style.css` file and all files and images will be restored on the next container launch.

## Screenshot

![Screenshot](screenshot.png)

## Notice

The logfile will look like this the first time the container is run (or if the files fritzbox.log and fritzbox.old are deleted):
```
Rateup WARNING: /usr/bin/rateup could not read the primary log file for fritzbox
Rateup WARNING: /usr/bin/rateup The backup log file for fritzbox was invalid as well
Rateup WARNING: /usr/bin/rateup Can't rename fritzbox.log to fritzbox.old updating log file
```
This is normal and expected behavior due to how `rateup` handles the file opening. More information in the [MRTG GitHub](https://github.com/oetiker/mrtg/blob/master/src/src/rateup.c#L1328)