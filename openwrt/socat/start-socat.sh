#!/bin/sh

# /root/socat/start-socat.sh
# /etc/init.d/socat

SOCAT_BIN="/root/socat/socat"
SERIAL_DEV="/dev/ttyACM0"
TCP_PORT="4403"
BAUD_RATE="115200"

logger -t socat-init "Waiting for $SERIAL_DEV"

while [ ! -e "$SERIAL_DEV" ]; do
    sleep 2
done

logger -t socat-init "Radio detected on $SERIAL_DEV"
logger -t socat-init "Starting TCP gateway on port $TCP_PORT"

exec "$SOCAT_BIN" \
    TCP-LISTEN:${TCP_PORT},reuseaddr,fork \
    FILE:${SERIAL_DEV},b${BAUD_RATE},raw,echo=0