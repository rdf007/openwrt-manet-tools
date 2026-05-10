#!/bin/sh

################################
# CONFIG
################################

LOGDIR="/www/data"
LOGFILE="$LOGDIR/mesh_test_log.csv"

MESHIF="wlan1"

mkdir -p "$LOGDIR"

################################
# MESH STATION STATS
################################

STATS=$(iw dev $MESHIF station dump)

RSSI=$(echo "$STATS" \
| awk '/^[[:space:]]signal:/ {print $2; exit}')

AVG=$(echo "$STATS" \
| awk '/signal avg/ {print $3; exit}')

ACK=$(echo "$STATS" \
| awk '/avg ack signal/ {print $4; exit}')

TXRATE=$(echo "$STATS" \
| sed -n 's/.*tx bitrate:[[:space:]]*//p' \
| head -1)

RXRATE=$(echo "$STATS" \
| sed -n 's/.*rx bitrate:[[:space:]]*//p' \
| head -1)

################################
# GENERIC MCS PARSER
# Works for:
# HE-MCS / VHT-MCS / MCS
################################

TXMCS=$(echo "$TXRATE" \
| grep -oE 'MCS [0-9]+' \
| awk '{print $2}')

RXMCS=$(echo "$RXRATE" \
| grep -oE 'MCS [0-9]+' \
| awk '{print $2}')

RETRIES=$(echo "$STATS" \
| awk '/tx retries/ {print $3; exit}')

FAILED=$(echo "$STATS" \
| awk '/tx failed/ {print $3; exit}')

AIRTIME=$(echo "$STATS" \
| awk '/airtime link metric/ {print $5; exit}')

CONNECTED=$(echo "$STATS" \
| awk '/connected time/ {print $3; exit}')

################################
# SURVEY (NOISE/SNR/CHANNEL BUSY)
################################

SURVEY=$(iw dev $MESHIF survey dump)

NOISE=$(echo "$SURVEY" \
| awk '/\[in use\]/{f=1} f&&/noise/ {print $2; exit}')

ACTIVE=$(echo "$SURVEY" \
| awk '/\[in use\]/{f=1} f&&/active time/ {print $4; exit}')

BUSY=$(echo "$SURVEY" \
| awk '/\[in use\]/{f=1} f&&/busy time/ {print $4; exit}')

################################
# DERIVED METRICS
################################

if [ -n "$RSSI" ] && [ -n "$NOISE" ]; then
SNR=$((RSSI - NOISE))
else
SNR="-"
fi

if [ -n "$ACTIVE" ] && [ "$ACTIVE" -gt 0 ]; then
BUSYPCT=$((100 * BUSY / ACTIVE))
else
BUSYPCT="-"
fi

################################
# DEFAULTS
################################

[ -z "$RSSI" ] && RSSI="NoPeer"
[ -z "$AVG" ] && AVG="-"
[ -z "$ACK" ] && ACK="-"

[ -z "$TXRATE" ] && TXRATE="-"
[ -z "$RXRATE" ] && RXRATE="-"

[ -z "$TXMCS" ] && TXMCS="-"
[ -z "$RXMCS" ] && RXMCS="-"

[ -z "$RETRIES" ] && RETRIES="-"
[ -z "$FAILED" ] && FAILED="-"

[ -z "$AIRTIME" ] && AIRTIME="-"
[ -z "$CONNECTED" ] && CONNECTED="-"

[ -z "$NOISE" ] && NOISE="-"

STATUS=""

################################
# CAPTURE BUTTON
################################

if echo "$QUERY_STRING" | grep -q "run=1"; then

TIME=$(date +"%F %T")

if [ ! -f "$LOGFILE" ]; then

echo "time,rssi,avg,ack,noise,snr,busy_pct,txrate,rxrate,txmcs,rxmcs,retries,failed,airtime,connected" > "$LOGFILE"

fi

echo "$TIME,$RSSI,$AVG,$ACK,$NOISE,$SNR,$BUSYPCT,\"$TXRATE\",\"$RXRATE\",$TXMCS,$RXMCS,$RETRIES,$FAILED,$AIRTIME,$CONNECTED" >> "$LOGFILE"

STATUS="Measurement Saved"

fi

################################
# COUNT
################################

if [ -f "$LOGFILE" ]; then
COUNT=$(( $(wc -l < "$LOGFILE") - 1 ))
else
COUNT=0
fi

################################
# HTML
################################

echo "Content-type: text/html"
echo ""

cat <<EOF

<html>

<head>

<title>Mesh Range Test Dashboard</title>

</head>

<body style="
font-family:monospace;
padding:30px;
font-size:22px;
">

<h1>Mesh Range Test Dashboard</h1>

<form action="/cgi-bin/meshtest.sh">

<input
type="submit"
value="Refresh Metrics"
style="
font-size:26px;
padding:15px;
">

</form>

<hr>

<h2>RF Link</h2>

<p><b>RSSI:</b> $RSSI dBm</p>

<p><b>Signal Avg:</b> $AVG</p>

<p><b>Ack Signal:</b> $ACK</p>

<p><b>Noise:</b> $NOISE dBm</p>

<p><b>SNR:</b> $SNR dB</p>

<p><b>Channel Busy:</b> $BUSYPCT %</p>

<hr>

<h2>PHY / Mesh</h2>

<p><b>TX Rate:</b> $TXRATE</p>

<p><b>RX Rate:</b> $RXRATE</p>

<p><b>TX MCS:</b> $TXMCS</p>

<p><b>RX MCS:</b> $RXMCS</p>

<p><b>Retries:</b> $RETRIES</p>

<p><b>TX Fail Count:</b> $FAILED</p>

<p><b>Airtime Metric:</b> $AIRTIME</p>

<p><b>Connected:</b> $CONNECTED sec</p>

<hr>

<h2>$STATUS</h2>

<h3>Measurements saved: $COUNT</h3>

<form action="/cgi-bin/meshtest.sh" method="get">

<input
type="hidden"
name="run"
value="1">

<input
type="submit"
value="Capture Measurement"
style="
font-size:36px;
padding:30px;
">

</form>

<br>

<form action="/data/mesh_test_log.csv">

<input
type="submit"
value="Download CSV"
style="
font-size:30px;
padding:20px;
">

</form>

<hr>

<p>
CSV Path:
<a href="/data/mesh_test_log.csv">
/data/mesh_test_log.csv
</a>
</p>

</body>
</html>

EOF