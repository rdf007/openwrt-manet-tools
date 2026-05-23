#!/bin/sh

################################
# CONFIG
################################

LOGDIR="/www/data"
LOGFILE="$LOGDIR/mesh_test_log.csv"

MESHIF="wlan1"

mkdir -p "$LOGDIR"

################################
# MESH STATUS
################################

MESH_DISABLED=$(uci -q get wireless.wifinet0.disabled)

if [ "$MESH_DISABLED" = "1" ]; then

    PEERS=0

    MESHSTATE="DISABLED"
    MESHCOLOR="red"

    MESHLABEL="Enable Mesh"
    MESHBUTTONCOLOR="#ccffcc"

else

    STATION_INFO=$(iw dev $MESHIF station dump)

    PEERS=$(echo "$STATION_INFO" | grep -c "^Station")

    if echo "$STATION_INFO" | grep -q "mesh plink:[[:space:]]*ESTAB"; then

        MESHSTATE="CONNECTED"
        MESHCOLOR="green"

    elif echo "$STATION_INFO" | grep -q "mesh plink:[[:space:]]*BLOCKED"; then

        MESHSTATE="BLOCKED"
        MESHCOLOR="red"

    elif echo "$STATION_INFO" | grep -q "mesh plink:[[:space:]]*LISTEN"; then

        MESHSTATE="LISTEN"
        MESHCOLOR="orange"

    elif [ "$PEERS" -gt 0 ]; then

        MESHSTATE="DISCOVERING"
        MESHCOLOR="orange"

    else

        MESHSTATE="NO PEER"
        MESHCOLOR="red"

    fi

    MESHLABEL="Disable Mesh"
    MESHBUTTONCOLOR="#ffcccc"

fi

################################
# HANDLE GET / POST
################################

if [ "$REQUEST_METHOD" = "POST" ]; then

    POST_DATA=$(cat)

else

    POST_DATA="$QUERY_STRING"

fi

################################
# PARSE FORM DATA
################################

DISTANCE=$(echo "$POST_DATA" \
| sed -n 's/.*distance_m=\([^&]*\).*/\1/p')

LAT=$(echo "$POST_DATA" \
| sed -n 's/.*lat=\([^&]*\).*/\1/p')

LON=$(echo "$POST_DATA" \
| sed -n 's/.*lon=\([^&]*\).*/\1/p')

ACC=$(echo "$POST_DATA" \
| sed -n 's/.*acc=\([^&]*\).*/\1/p')

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
# TRAFFIC STATS
################################

RXBYTES=$(echo "$STATS" \
| awk '/rx bytes:/ {print $3; exit}')

TXBYTES=$(echo "$STATS" \
| awk '/tx bytes:/ {print $3; exit}')

RXPKTS=$(echo "$STATS" \
| awk '/rx packets:/ {print $3; exit}')

TXPKTS=$(echo "$STATS" \
| awk '/tx packets:/ {print $3; exit}')

RXDROP=$(echo "$STATS" \
| awk '/rx drop misc:/ {print $4; exit}')

################################
# SURVEY DATA
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

[ -z "$DISTANCE" ] && DISTANCE=""

[ -z "$LAT" ] && LAT=""
[ -z "$LON" ] && LON=""
[ -z "$ACC" ] && ACC=""

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

[ -z "$RXBYTES" ] && RXBYTES="-"
[ -z "$TXBYTES" ] && TXBYTES="-"

[ -z "$RXPKTS" ] && RXPKTS="-"
[ -z "$TXPKTS" ] && TXPKTS="-"

[ -z "$RXDROP" ] && RXDROP="-"

[ -z "$NOISE" ] && NOISE="-"

STATUS=""

################################
# MESH TOGGLE
################################

if echo "$POST_DATA" | grep -q "mesh_toggle=1"; then

    MESH_DISABLED=$(uci -q get wireless.wifinet0.disabled)

    if [ "$MESH_DISABLED" = "1" ]; then

        uci set wireless.wifinet0.disabled='0'

    else

        uci set wireless.wifinet0.disabled='1'

    fi

    uci commit wireless

    wifi reload

    echo "Status: 303 See Other"
    echo "Location: /cgi-bin/meshtest.sh"
    echo ""

    exit 0

fi

################################
# CAPTURE BUTTON
################################

if echo "$POST_DATA" | grep -q "run=1"; then

    TIME=$(date +"%F %T")
    EPOCH=$(date +%s)

    if [ ! -f "$LOGFILE" ]; then

        echo "distance_m,lat,lon,accuracy_m,time,epoch,rssi,avg,ack,noise,snr,busy_pct,txrate,rxrate,txmcs,rxmcs,retries,failed,airtime,connected,tx_bytes,rx_bytes,tx_packets,rx_packets,rx_drop_misc" > "$LOGFILE"

    fi

    echo "$DISTANCE,$LAT,$LON,$ACC,$TIME,$EPOCH,$RSSI,$AVG,$ACK,$NOISE,$SNR,$BUSYPCT,\"$TXRATE\",\"$RXRATE\",$TXMCS,$RXMCS,$RETRIES,$FAILED,$AIRTIME,$CONNECTED,$TXBYTES,$RXBYTES,$TXPKTS,$RXPKTS,$RXDROP" >> "$LOGFILE"

    ################################################
    # REDIRECT AFTER POST
    ################################################

    echo "Status: 303 See Other"
    echo "Location: /cgi-bin/meshtest.sh"
    echo ""

    exit 0

fi

################################
# CLEAR CSV
################################

if echo "$POST_DATA" | grep -q "clear=1"; then

    rm -f "$LOGFILE"

    ################################################
    # REDIRECT AFTER POST
    ################################################

    echo "Status: 303 See Other"
    echo "Location: /cgi-bin/meshtest.sh"
    echo ""

    exit 0

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
# HTML OUTPUT
################################

echo "Content-type: text/html"
echo ""

cat <<EOF

<html>

<head>

<title>Mesh Range Test Dashboard</title>

<meta name="viewport" content="width=device-width, initial-scale=1">

<script>

function updateLocation() {

    navigator.geolocation.getCurrentPosition(

        function(position) {

            //////////////////////////////////////////////////
            // STORE GPS INTO FORM
            //////////////////////////////////////////////////

            document.getElementById("lat").value =
                position.coords.latitude;

            document.getElementById("lon").value =
                position.coords.longitude;

            document.getElementById("acc").value =
                position.coords.accuracy;

            //////////////////////////////////////////////////
            // UPDATE STATUS
            //////////////////////////////////////////////////

            document.getElementById("gps_status").innerHTML =
                "GPS OK";

            document.getElementById("gps_status").style.color =
                "green";

            document.getElementById("gps_lat").innerHTML =
                position.coords.latitude;

            document.getElementById("gps_lon").innerHTML =
                position.coords.longitude;

            document.getElementById("gps_acc").innerHTML =
                position.coords.accuracy;

        },

        function(error) {

            document.getElementById("gps_status").innerHTML =
                "GPS ERROR";

            document.getElementById("gps_status").style.color =
                "red";

            console.log(
                "GPS Error:",
                error.message
            );

        }

    );
}

window.onload = updateLocation;

</script>

</head>

<body style="
font-family:monospace;
padding:30px;
font-size:22px;
">

<h1>Mesh Range Test Dashboard</h1>

<hr>

<h2>Mesh Status</h2>

<p>

<b>Status:</b>

<span style="
font-weight:bold;
color:$MESHCOLOR;
">

$MESHSTATE

</span>

</p>

<p>

<b>Peers:</b>

$PEERS

</p>

<form action="/cgi-bin/meshtest.sh" method="post">

<input
type="hidden"
name="mesh_toggle"
value="1">

<input
type="submit"
value="$MESHLABEL"
style="
font-size:26px;
padding:15px;
background-color:$MESHBUTTONCOLOR;
">

</form>

<form action="/cgi-bin/meshtest.sh" method="get">

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

<h2>Traffic Statistics</h2>

<p><b>TX Bytes:</b> $TXBYTES</p>

<p><b>RX Bytes:</b> $RXBYTES</p>

<p><b>TX Packets:</b> $TXPKTS</p>

<p><b>RX Packets:</b> $RXPKTS</p>

<p><b>RX Drop Misc:</b> $RXDROP</p>

<hr>

<h2>GPS</h2>

<p><b>Status:</b> <span id="gps_status">Waiting...</span></p>

<p><b>Latitude:</b> <span id="gps_lat">$LAT</span></p>

<p><b>Longitude:</b> <span id="gps_lon">$LON</span></p>

<p><b>Accuracy:</b> <span id="gps_acc">$ACC</span> m</p>

<hr>

<h2>$STATUS</h2>

<h3>Measurements saved: $COUNT</h3>

<form action="/cgi-bin/meshtest.sh" method="post">

<input
type="hidden"
name="run"
value="1">

<input
type="hidden"
id="lat"
name="lat">

<input
type="hidden"
id="lon"
name="lon">

<input
type="hidden"
id="acc"
name="acc">

<p>

<b>Distance (m):</b>

<input
type="number"
name="distance_m"
style="
font-size:28px;
padding:10px;
width:200px;
">

</p>

<input
type="submit"
value="Capture Measurement"
style="
font-size:36px;
padding:30px;
">

</form>

<br>

<form action="/data/mesh_test_log.csv" method="get">

<input
type="submit"
value="Download CSV"
style="
font-size:30px;
padding:20px;
">

</form>

<br>

<form action="/map.html" method="get" target="_blank">

<input
type="submit"
value="Open RF Map"
style="
font-size:30px;
padding:20px;
">

</form>

<br>

<form action="/cgi-bin/meshtest.sh" method="post">

<input
type="hidden"
name="clear"
value="1">

<input
type="submit"
value="Clear CSV Log"
style="
font-size:28px;
padding:20px;
background-color:#ffcccc;
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