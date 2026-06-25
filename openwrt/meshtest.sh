#!/bin/sh

################################
# CONFIG
################################

LOGDIR="/www/data"
LOGFILE="$LOGDIR/mesh_test_log.csv"

MESHIF="wlan1"

# LORA CONFIG
LORA_DEV="/dev/ttyACM0"
LORA_PORT="4403"

################################
# LORA STATUS
################################

if [ -c "$LORA_DEV" ]; then
    LORA_SERIAL_STATE="CONNECTED"
    LORA_SERIAL_COLOR="#28a745"
else
    LORA_SERIAL_STATE="DISCONNECTED"
    LORA_SERIAL_COLOR="#dc3545"
fi

if netstat -an | grep -q ":$LORA_PORT .* LISTEN"; then
    LORA_TCP_STATE="ACTIVE"
    LORA_TCP_COLOR="#28a745"
else
    LORA_TCP_STATE="INACTIVE"
    LORA_TCP_COLOR="#dc3545"
fi

mkdir -p "$LOGDIR"

################################
# MESH STATUS
################################

STATION_INFO=$(iw dev "$MESHIF" station dump 2>/dev/null)
SURVEY_INFO=$(iw dev "$MESHIF" survey dump 2>/dev/null)
MESH_DISABLED=$(uci -q get wireless.wifinet0.disabled)

if [ "$MESH_DISABLED" = "1" ]; then
    PEERS=0
    MESHSTATE="DISABLED"
    MESHCOLOR="#dc3545"
    MESHLABEL="Enable Mesh"
    MESHBUTTONCOLOR="#28a745"
else
    PEERS=$(echo "$STATION_INFO" | grep -c "^Station")

    if echo "$STATION_INFO" | grep -q "mesh plink:[[:space:]]*ESTAB"; then
        MESHSTATE="CONNECTED"
        MESHCOLOR="#28a745"
    elif echo "$STATION_INFO" | grep -q "mesh plink:[[:space:]]*BLOCKED"; then
        MESHSTATE="BLOCKED"
        MESHCOLOR="#dc3545"
    elif echo "$STATION_INFO" | grep -q "mesh plink:[[:space:]]*LISTEN"; then
        MESHSTATE="LISTEN"
        MESHCOLOR="#ffc107"
    elif [ "$PEERS" -gt 0 ]; then
        MESHSTATE="DISCOVERING"
        MESHCOLOR="#ffc107"
    else
        MESHSTATE="NO PEER"
        MESHCOLOR="#dc3545"
    fi

    MESHLABEL="Disable Mesh"
    MESHBUTTONCOLOR="#dc3545"
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

LAT=$(echo "$POST_DATA" | sed -n 's/.*lat=\([^&]*\).*/\1/p')
LON=$(echo "$POST_DATA" | sed -n 's/.*lon=\([^&]*\).*/\1/p')
ACC=$(echo "$POST_DATA" | sed -n 's/.*acc=\([^&]*\).*/\1/p')
PHONE_TIME=$(echo "$POST_DATA" | sed -n 's/.*phone_time=\([^&]*\).*/\1/p' | sed 's/%20/ /g' | sed 's/%3A/:/g')

# Correção Automática de Hora via smartphone
if [ -n "$PHONE_TIME" ]; then
    date -s "$PHONE_TIME" >/dev/null 2>&1
fi

################################
# MESH STATION STATS
################################

RSSI=$(echo "$STATION_INFO" | awk '/^[[:space:]]signal:/ {print $2; exit}')
AVG=$(echo "$STATION_INFO" | awk '/signal avg/ {print $3; exit}')
ACK=$(echo "$STATION_INFO" | awk '/avg ack signal/ {print $4; exit}')
TXRATE=$(echo "$STATION_INFO" | sed -n 's/.*tx bitrate:[[:space:]]*//p' | head -1)
RXRATE=$(echo "$STATION_INFO" | sed -n 's/.*rx bitrate:[[:space:]]*//p' | head -1)

TXMCS=$(echo "$TXRATE" | grep -oE 'MCS [0-9]+' | awk '{print $2}')
RXMCS=$(echo "$RXRATE" | grep -oE 'MCS [0-9]+' | awk '{print $2}')
RETRIES=$(echo "$STATION_INFO" | awk '/tx retries/ {print $3; exit}')
FAILED=$(echo "$STATION_INFO" | awk '/tx failed/ {print $3; exit}')
AIRTIME=$(echo "$STATION_INFO" | awk '/airtime link metric/ {print $5; exit}')
CONNECTED=$(echo "$STATION_INFO" | awk '/connected time/ {print $3; exit}')

RXBYTES=$(echo "$STATION_INFO" | awk '/rx bytes:/ {print $3; exit}')
TXBYTES=$(echo "$STATION_INFO" | awk '/tx bytes:/ {print $3; exit}')
RXPKTS=$(echo "$STATION_INFO" | awk '/rx packets:/ {print $3; exit}')
TXPKTS=$(echo "$STATION_INFO" | awk '/tx packets:/ {print $3; exit}')
RXDROP=$(echo "$STATION_INFO" | awk '/rx drop misc:/ {print $4; exit}')

NOISE=$(echo "$SURVEY_INFO" | awk '/\[in use\]/{f=1} f&&/noise/ {print $2; exit}')
ACTIVE=$(echo "$SURVEY_INFO" | awk '/\[in use\]/{f=1} f&&/active time/ {print $4; exit}')
BUSY=$(echo "$SURVEY_INFO" | awk '/\[in use\]/{f=1} f&&/busy time/ {print $4; exit}')

if [ -n "$RSSI" ] && [ "$RSSI" -eq "$RSSI" ] 2>/dev/null && [ -n "$NOISE" ] && [ "$NOISE" -eq "$NOISE" ] 2>/dev/null; then
    SNR=$((RSSI - NOISE))
else
    SNR="-"
fi

if [ -n "$ACTIVE" ] && [ "$ACTIVE" -gt 0 ]; then
    BUSYPCT=$((100 * BUSY / ACTIVE))
else
    BUSYPCT="-"
fi

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

################################
# ACTIONS (TOGGLE, CAPTURE, SAVE, CLEAR)
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
    echo "Status: 303 See Other\nLocation: /cgi-bin/meshtest.sh\n\n"
    exit 0
fi

if echo "$POST_DATA" | grep -q "run=1"; then
    TIME=$(date +"%F %T")
    EPOCH=$(date +%s)
    PEER_LAT=""
    PEER_LON=""
    P_IPS=$(ip neigh show | awk '/REACHABLE|STALE|DELAY/ {print $1}' | sort -u)
    M_IPS=$(ifconfig | sed -n 's/.*dr:\([0-9.]*\).*/\1/p')

    for P_IP in $P_IPS; do
        case "$P_IP" in *:* ) continue ;; esac
        echo "$M_IPS" | grep -q "$P_IP" && continue
        R_JSON=$(wget -qO- --timeout=1 "http://$P_IP/location.json" 2>/dev/null)
        if [ -n "$R_JSON" ]; then
            PEER_LAT=$(echo "$R_JSON" | sed -n 's/.*"lat":[[:space:]]*"\([^"]*\)".*/\1/p')
            PEER_LON=$(echo "$R_JSON" | sed -n 's/.*"lon":[[:space:]]*"\([^"]*\)".*/\1/p')
            [ -n "$PEER_LAT" ] && break
        fi
    done

    if [ ! -f "$LOGFILE" ]; then
        echo "lat,lon,accuracy_m,time,epoch,rssi,avg,ack,noise,snr,busy_pct,txrate,rxrate,txmcs,rxmcs,retries,failed,airtime,connected,tx_bytes,rx_bytes,tx_packets,rx_packets,rx_drop_misc,peer_lat,peer_lon" > "$LOGFILE"
    fi
    echo "$LAT,$LON,$ACC,$TIME,$EPOCH,$RSSI,$AVG,$ACK,$NOISE,$SNR,$BUSYPCT,\"$TXRATE\",\"$RXRATE\",$TXMCS,$RXMCS,$RETRIES,$FAILED,$AIRTIME,$CONNECTED,$TXBYTES,$RXBYTES,$TXPKTS,$RXPKTS,$RXDROP,$PEER_LAT,$PEER_LON" >> "$LOGFILE"
    
    echo "Status: 303 See Other\nLocation: /cgi-bin/meshtest.sh\n\n"
    exit 0
fi

if echo "$POST_DATA" | grep -q "save_pos=1"; then
    TIME=$(date +"%F %T")
    LOCATION_FILE="/www/location.json"
    cat > "$LOCATION_FILE" <<EOF
{ "lat": "$LAT", "lon": "$LON", "acc": "$ACC", "time": "$TIME" }
EOF
    chmod 644 "$LOCATION_FILE"
    echo "Status: 303 See Other\nLocation: /cgi-bin/meshtest.sh\n\n"
    exit 0
fi

if echo "$POST_DATA" | grep -q "clear=1"; then
    rm -f "$LOGFILE"
    echo "Status: 303 See Other\nLocation: /cgi-bin/meshtest.sh\n\n"
    exit 0
fi

if [ -f "$LOGFILE" ]; then
    COUNT=$(( $(wc -l < "$LOGFILE") - 1 ))
else
    COUNT=0
fi

################################
# REMOTE NODES DATA
################################

REMOTE_NODES_HTML=""
PEER_IPS=$(ip neigh show | awk '/REACHABLE|STALE|DELAY/ {print $1}' | sort -u)
MY_IPS=$(ifconfig | sed -n 's/.*dr:\([0-9.]*\).*/\1/p')

for IP in $PEER_IPS; do
    case "$IP" in *:* ) continue ;; esac
    echo "$MY_IPS" | grep -q "$IP" && continue
    REMOTE_JSON=$(wget -qO- --timeout=1 "http://$IP/location.json" 2>/dev/null)
    if [ -n "$REMOTE_JSON" ]; then
        R_LAT=$(echo "$REMOTE_JSON" | sed -n 's/.*"lat":[[:space:]]*"\([^"]*\)".*/\1/p')
        R_LON=$(echo "$REMOTE_JSON" | sed -n 's/.*"lon":[[:space:]]*"\([^"]*\)".*/\1/p')
        R_TIME=$(echo "$REMOTE_JSON" | sed -n 's/.*"time":[[:space:]]*"\([^"]*\)".*/\1/p')
        if [ -n "$R_LAT" ]; then
            REMOTE_NODES_HTML="${REMOTE_NODES_HTML}<div class='metric-row'><span class='metric-label'>$IP:</span><span class='metric-value' style='font-size:12px;'>$R_LAT, $R_LON<br><small>$R_TIME</small></span></div>"
        fi
    fi
done

SYSTEM_CURRENT_TIME=$(date +"%F %T")

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
<meta name="theme-color" content="#222">

<script>
function getFormattedPhoneTime() {
    let d = new Date();
    let pad = (n) => n < 10 ? '0' + n : n;
    return d.getFullYear() + '-' + 
           pad(d.getMonth() + 1) + '-' + 
           pad(d.getDate()) + ' ' + 
           pad(d.getHours()) + ':' + 
           pad(d.getMinutes()) + ':' + 
           pad(d.getSeconds());
}

function updateLocation() {
    navigator.geolocation.getCurrentPosition(
        function(position) {
            document.getElementById("lat").value = position.coords.latitude;
            document.getElementById("lon").value = position.coords.longitude;
            document.getElementById("acc").value = position.coords.accuracy;

            if (document.getElementById("lat_pos")) {
                document.getElementById("lat_pos").value = position.coords.latitude;
                document.getElementById("lon_pos").value = position.coords.longitude;
                document.getElementById("acc_pos").value = position.coords.accuracy;
            }

            document.getElementById("gps_status").innerHTML = "GPS OK";
            document.getElementById("gps_status").style.color = "green";
            document.getElementById("gps_lat").innerHTML = position.coords.latitude;
            document.getElementById("gps_lon").innerHTML = position.coords.longitude;
            document.getElementById("gps_acc").innerHTML = position.coords.accuracy;
        },
        function(error) {
            document.getElementById("gps_status").innerHTML = "GPS ERROR";
            document.getElementById("gps_status").style.color = "red";
        },
        { enableHighAccuracy: true, timeout: 5000 }
    );
}

// SUBMIT ASSÍNCRONO UNIVERSAL (Intercepta POSTs para mitigar o timeout do CGI)
function handleAsyncSubmit(event, formId, buttonId, loadingText, fallbackColor) {
    event.preventDefault();
    
    let timeInput = document.getElementById(formId + "-time");
    if(timeInput) {
        timeInput.value = getFormattedPhoneTime();
    }
    
    let btn = document.getElementById(buttonId);
    let originalValue = btn.value;
    btn.value = loadingText;
    btn.style.background = "#ffc107";
    btn.style.color = "#000";
    btn.disabled = true;

    let form = document.getElementById(formId);
    let formData = new FormData(form);
    let searchParams = new URLSearchParams(formData);

    fetch("/cgi-bin/meshtest.sh", {
        method: "POST",
        body: searchParams
    })
    .then(() => {
        setTimeout(() => { window.location.reload(); }, 800);
    })
    .catch(() => {
        btn.value = originalValue;
        btn.style.background = fallbackColor || "#6c757d";
        btn.style.color = "white";
        btn.disabled = false;
        alert("Erro na comunicação com o roteador. Tente novamente.");
    });
}

// DISPARADOR DE DOWNLOAD SEGURO NO ANDROID (Evita erro de Gateway no redirecionamento)
function triggerSecureDownload() {
    let btn = document.getElementById("btn-download-id");
    let originalText = btn.value;
    btn.value = "Downloading...";
    btn.disabled = true;

    fetch("/data/mesh_test_log.csv")
    .then(response => {
        if (!response.ok) throw new Error();
        return response.blob();
    })
    .then(blob => {
        let url = window.URL.createObjectURL(blob);
        let a = document.createElement('a');
        a.href = url;
        a.download = "mesh_test_log.csv";
        document.body.appendChild(a);
        a.click();
        a.remove();
        window.URL.revokeObjectURL(url);
        btn.value = originalText;
        btn.disabled = false;
    })
    .catch(() => {
        alert("O arquivo CSV ainda não existe ou está vazio (capture dados primeiro).");
        btn.value = originalText;
        btn.disabled = false;
    });
}

window.onload = function() {
    updateLocation();
    setInterval(updateLocation, 5000);
};
</script>

<style>
body { font-family: -apple-system, system-ui, sans-serif; padding: 10px; background: #f0f2f5; color: #1c1e21; margin: 0; }
.container { max-width: 600px; margin: auto; }
.card { background: white; padding: 15px; border-radius: 12px; margin-bottom: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
h1 { font-size: 24px; text-align: center; margin: 20px 0; }
h2 { font-size: 18px; margin: 0 0 10px 0; color: #444; border-bottom: 2px solid #eee; padding-bottom: 5px; }
.metric-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f0f0f0; }
.metric-row:last-child { border-bottom: none; }
.metric-label { font-weight: 600; color: #606770; font-size: 16px; }
.metric-value { font-weight: bold; font-family: monospace; font-size: 18px; }
.status-badge { font-weight: bold; text-transform: uppercase; }
input[type="submit"], button.btn-download { width: 100%; border: none; border-radius: 8px; font-weight: bold; cursor: pointer; display: block; box-sizing: border-box; text-align: center; }
.btn-capture { background: #007bff; color: white; padding: 20px; font-size: 24px; margin-top: 10px; }
.btn-refresh { background: #6c757d; color: white; padding: 15px; font-size: 18px; margin-top: 10px; }
.btn-toggle { color: white; padding: 15px; font-size: 18px; margin-bottom: 10px; }
.btn-save-pos { background: #6f42c1; color: white; padding: 15px; font-size: 18px; margin-top: 10px; }
.btn-download { background: #28a745; color: white; padding: 15px; font-size: 18px; }
.btn-clear { background: #dc3545; color: white; padding: 12px; font-size: 16px; margin-top: 20px; }
</style>
</head>

<body>
<div class="container">

<h1>Mesh Range Test</h1>

<div class="card" style="border: 2px solid #007bff;">
    <h2>Data Capture ($COUNT saved)</h2>
<form id="capture-form" onsubmit="handleAsyncSubmit(event, 'capture-form', 'btn-capture-id', 'Saving to CSV...', '#007bff');">
<input type="hidden" name="run" value="1">
<input type="hidden" id="lat" name="lat">
<input type="hidden" id="lon" name="lon">
<input type="hidden" id="acc" name="acc">
<input type="hidden" id="capture-form-time" name="phone_time">
<input type="submit" id="btn-capture-id" value="Capture Measurement" class="btn-capture">
</form>
</div>

<div class="card">
    <h2>Remote Node Locations</h2>
    ${REMOTE_NODES_HTML:-<div class='metric-row'><span class='metric-label' style='color:#999;'>No remote location data found.</span></div>}
</div>

<div class="card">
    <h2>GPS & Router Clock</h2>
    <div class="metric-row"><span class="metric-label">Router Time:</span><span class="metric-value" style="color: #6f42c1;">$SYSTEM_CURRENT_TIME</span></div>
    <div style="border-top: 1px dashed #ddd; margin: 8px 0;"></div>
    <div class="metric-row"><span class="metric-label">Status:</span><span id="gps_status" class="metric-value">Waiting...</span></div>
    <div class="metric-row"><span class="metric-label">Accuracy:</span><span class="metric-value"><span id="gps_acc">$ACC</span> m</span></div>
    <div class="metric-row"><span class="metric-label">Lat:</span><span id="gps_lat" class="metric-value" style="font-size:14px;">$LAT</span></div>
    <div class="metric-row"><span class="metric-label">Lon:</span><span id="gps_lon" class="metric-value" style="font-size:14px;">$LON</span></div>
</div>

<div class="card">
    <h2>Network Visibility</h2>
<form id="share-form" onsubmit="handleAsyncSubmit(event, 'share-form', 'btn-share-id', 'Sharing Position...', '#6f42c1');">
<input type="hidden" name="save_pos" value="1">
<input type="hidden" id="lat_pos" name="lat">
<input type="hidden" id="lon_pos" name="lon">
<input type="hidden" id="acc_pos" name="acc">
<input type="hidden" id="share-form-time" name="phone_time">
<input type="submit" id="btn-share-id" value="Save & Share My Position" class="btn-save-pos">
</form>
<p style="font-size:11px; color:#777; margin-top:10px;">Saves to /www/location.json for other nodes to discover.</p>
</div>

<div class="card">
    <h2>RF Link</h2>
    <div class="metric-row"><span class="metric-label">RSSI:</span><span class="metric-value">$RSSI dBm</span></div>
    <div class="metric-row"><span class="metric-label">Signal Avg:</span><span class="metric-value">$AVG</span></div>
    <div class="metric-row"><span class="metric-label">SNR:</span><span class="metric-value">$SNR dB</span></div>
    <div class="metric-row"><span class="metric-label">Noise:</span><span class="metric-value">$NOISE dBm</span></div>
    <div class="metric-row"><span class="metric-label">Channel Busy:</span><span class="metric-value">$BUSYPCT %</span></div>
</div>

<div class="card">
    <h2>PHY / Mesh</h2>
    <div class="metric-row"><span class="metric-label">TX Rate:</span><span class="metric-value">$TXRATE</span></div>
    <div class="metric-row"><span class="metric-label">TX MCS:</span><span class="metric-value">$TXMCS</span></div>
    <div class="metric-row"><span class="metric-label">Retries:</span><span class="metric-value">$RETRIES</span></div>
    <div class="metric-row"><span class="metric-label">Airtime Metric:</span><span class="metric-value">$AIRTIME</span></div>
</div>

<div class="card">
    <h2>System Status (Mesh & LoRa)</h2>
    <div class="metric-row">
        <span class="metric-label">Wi-Fi Mesh Status:</span>
        <span class="status-badge" style="color:$MESHCOLOR;">$MESHSTATE</span>
    </div>
    <div class="metric-row">
        <span class="metric-label">Wi-Fi Peers:</span>
        <span class="metric-value">$PEERS</span>
    </div>
    <div style="border-top: 1px dashed #ddd; margin: 10px 0;"></div>
    <div class="metric-row">
        <span class="metric-label">Radio ($LORA_DEV):</span>
        <span class="status-badge" style="color:$LORA_SERIAL_COLOR;">$LORA_SERIAL_STATE</span>
    </div>
    <div class="metric-row">
        <span class="metric-label">TCP Gateway ($LORA_PORT):</span>
        <span class="status-badge" style="color:$LORA_TCP_COLOR;">$LORA_TCP_STATE</span>
    </div>
    <br>
<form id="toggle-form" onsubmit="handleAsyncSubmit(event, 'toggle-form', 'btn-toggle-id', 'Applying...', '$MESHBUTTONCOLOR');">
<input type="hidden" name="mesh_toggle" value="1">
<input type="submit" id="btn-toggle-id" value="$MESHLABEL" class="btn-toggle" style="background-color:$MESHBUTTONCOLOR;">
</form>
<form id="refresh-form" onsubmit="handleAsyncSubmit(event, 'refresh-form', 'btn-refresh-id', 'Refreshing...', '#6c757d');">
<input type="submit" id="btn-refresh-id" value="Refresh Metrics" class="btn-refresh">
</form>
</div>

<div class="card">
    <h2>Tools</h2>
<br>
<button id="btn-download-id" onclick="triggerSecureDownload();" class="btn-download">Download CSV</button>
<br>
<form id="clear-form" onsubmit="handleAsyncSubmit(event, 'clear-form', 'btn-clear-id', 'Clearing Log...', '#dc3545');">
<input type="hidden" name="clear" value="1">
<input type="submit" id="btn-clear-id" value="Clear CSV Log" class="btn-clear">
</form>
</div>

<div style="text-align:center; color:#888; padding:20px; font-size:12px;">
    CSV Path: /data/mesh_test_log.csv
</div>

</div>
</body>
</html>
EOF