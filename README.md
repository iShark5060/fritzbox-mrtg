# Monitor your FRITZ!Box

![Static Badge](https://img.shields.io/badge/Alpine-latest-red?style=for-the-badge) ![Static Badge](https://img.shields.io/badge/APK-green?style=for-the-badge&label=RRDtool) ![Static Badge](https://img.shields.io/badge/APK-blue?style=for-the-badge&label=MRTG) ![Static Badge](https://img.shields.io/badge/APK-yellow?style=for-the-badge&label=NGINX)

Simple, lightweight script that uses `upnp2mrtg` to communicate with your Fritz!Box and collect bandwidth data. It's then sent to `rrdtool` and `mrtg` for pretty graphs and finally displayed to a simple website using `nginx` (with a little help of `14all.cgi`).

The whole project is based on the work of [Thorsten Kukuk](https://github.com/thkukuk/fritzbox-monitoring/)

## About

This is my first docker container project from "scratch". It's fully based on the project from [Thorsten Kukuk](https://github.com/thkukuk/fritzbox-monitoring/), but I've added and changed many parts over the iterations, that you can't really compare the two much anymore.
The container is using an alpine base image, RRDtool and MRTG to display a traffic graph on a website serverd by NGINX. Supports SSL and dark mode.

The Fritzbox-MRTG project is licensed under [GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)

Fritzbox-monitoring base project by [Thorsten Kukuk](https://github.com/thkukuk/fritzbox-monitoring/)
14all.cgi used from [Rainer Bawidamann](https://sourceforge.net/projects/my14all/)
upnp2mrts used from [Michael Tomschitz](http://www.ANetzB.de/upnp2mrtg/) (Site seems to be down at the moment)

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
      - AUTOSCALE=min
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
  -e AUTOSCALE=min \
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
| AUTOSCALE  | choose between `min`, `max`, `both`, `off` to autoscale graph. Min is best for low traffic. | | `min` |

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
