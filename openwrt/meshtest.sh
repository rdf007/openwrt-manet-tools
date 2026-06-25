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
    LORA_SERIAL_BADGE="ok"
else
    LORA_SERIAL_STATE="DISCONNECTED"
    LORA_SERIAL_BADGE="err"
fi

if netstat -an | grep -q ":$LORA_PORT .* LISTEN"; then
    LORA_TCP_STATE="ACTIVE"
    LORA_TCP_BADGE="ok"
else
    LORA_TCP_STATE="INACTIVE"
    LORA_TCP_BADGE="err"
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
    MESHBADGE="off"
    MESHLABEL="Enable mesh"
    MESHBTNCLASS="btn-success"
    MESHBTNICON="ti-wifi"
else
    PEERS=$(echo "$STATION_INFO" | grep -c "^Station")

    if echo "$STATION_INFO" | grep -q "mesh plink:[[:space:]]*ESTAB"; then
        MESHSTATE="CONNECTED"
        MESHBADGE="ok"
    elif echo "$STATION_INFO" | grep -q "mesh plink:[[:space:]]*BLOCKED"; then
        MESHSTATE="BLOCKED"
        MESHBADGE="err"
    elif echo "$STATION_INFO" | grep -q "mesh plink:[[:space:]]*LISTEN"; then
        MESHSTATE="LISTEN"
        MESHBADGE="warn"
    elif [ "$PEERS" -gt 0 ]; then
        MESHSTATE="DISCOVERING"
        MESHBADGE="warn"
    else
        MESHSTATE="NO PEER"
        MESHBADGE="err"
    fi

    MESHLABEL="Disable mesh"
    MESHBTNCLASS="btn-danger"
    MESHBTNICON="ti-wifi-off"
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
PHONE_TIME=$(echo "$POST_DATA" | sed -n 's/.*phone_time=\([^&]*\).*/\1/p' | sed -e 's/%20/ /g' -e 's/%3A/:/g')

# Sync router clock from smartphone time
if [ -n "$PHONE_TIME" ]; then
    date -s "$PHONE_TIME" >/dev/null 2>&1
fi

################################
# MESH STATION STATS
################################

RSSI=$(echo "$STATION_INFO" | awk '/^[[:space:]]signal:/ {print $2; exit}')
AVG=$(echo "$STATION_INFO" | awk '/signal avg/ {print $3; exit}')
ACK=$(echo "$STATION_INFO" | awk '/avg avg ack signal/ {print $4; exit}')
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
    SNR="—"
fi

if [ -n "$ACTIVE" ] && [ "$ACTIVE" -gt 0 ]; then
    BUSYPCT=$((100 * BUSY / ACTIVE))
else
    BUSYPCT="—"
fi

[ -z "$LAT" ] && LAT=""
[ -z "$LON" ] && LON=""
[ -z "$ACC" ] && ACC=""
[ -z "$RSSI" ] && RSSI="—"
[ -z "$AVG" ] && AVG="—"
[ -z "$ACK" ] && ACK="—"
[ -z "$TXRATE" ] && TXRATE="—"
[ -z "$RXRATE" ] && RXRATE="—"
[ -z "$TXMCS" ] && TXMCS="—"
[ -z "$RXMCS" ] && RXMCS="—"
[ -z "$RETRIES" ] && RETRIES="—"
[ -z "$FAILED" ] && FAILED="—"
[ -z "$AIRTIME" ] && AIRTIME="—"
[ -z "$CONNECTED" ] && CONNECTED="—"
[ -z "$RXBYTES" ] && RXBYTES="—"
[ -z "$TXBYTES" ] && TXBYTES="—"
[ -z "$RXPKTS" ] && RXPKTS="—"
[ -z "$TXPKTS" ] && TXPKTS="—"
[ -z "$RXDROP" ] && RXDROP="—"
[ -z "$NOISE" ] && NOISE="—"
[ -z "$BUSYPCT" ] && BUSYPCT="—"

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
    echo -e "Status: 303 See Other\r\nLocation: /cgi-bin/meshtest.sh\r\n\r\n"
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

    echo -e "Status: 303 See Other\r\nLocation: /cgi-bin/meshtest.sh\r\n\r\n"
    exit 0
fi

if echo "$POST_DATA" | grep -q "save_pos=1"; then
    TIME=$(date +"%F %T")
    LOCATION_FILE="/www/location.json"
    cat > "$LOCATION_FILE" <<EOF
{ "lat": "$LAT", "lon": "$LON", "acc": "$ACC", "time": "$TIME" }
EOF
    chmod 644 "$LOCATION_FILE"
    echo -e "Status: 303 See Other\r\nLocation: /cgi-bin/meshtest.sh\r\n\r\n"
    exit 0
fi

if echo "$POST_DATA" | grep -q "clear=1"; then
    rm -f "$LOGFILE"
    echo -e "Status: 303 See Other\r\nLocation: /cgi-bin/meshtest.sh\r\n\r\n"
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
            REMOTE_NODES_HTML="${REMOTE_NODES_HTML}
            <div class='peer-row'>
              <span class='peer-ip'>$IP</span>
              <span class='peer-coords'>$R_LAT, $R_LON<br><small>$R_TIME</small></span>
            </div>"
        fi
    fi
done

SYSTEM_CURRENT_TIME=$(date +"%F %T")

################################
# HTML OUTPUT
################################

echo "Content-type: text/html"
echo ""

cat <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Mesh Range Test</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#0f0f0f">

<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg:       #0f0f0f;
    --surface:  #1a1a1a;
    --surface2: #222222;
    --border:   rgba(255,255,255,0.08);
    --border-s: rgba(255,255,255,0.14);
    --text:     #f0f0f0;
    --muted:    #888;
    --dim:      #555;

    --blue:     #4fa3e8;
    --blue-bg:  rgba(79,163,232,0.12);
    --blue-bd:  rgba(79,163,232,0.25);

    --green:    #4caf7d;
    --green-bg: rgba(76,175,125,0.12);
    --green-bd: rgba(76,175,125,0.25);

    --red:      #e05757;
    --red-bg:   rgba(224,87,87,0.12);
    --red-bd:   rgba(224,87,87,0.25);

    --yellow:   #e0a540;
    --yellow-bg:rgba(224,165,64,0.12);
    --yellow-bd:rgba(224,165,64,0.25);

    --purple:   #9b7fe8;
    --purple-bg:rgba(155,127,232,0.12);
    --purple-bd:rgba(155,127,232,0.25);
  }

  body {
    background: var(--bg);
    color: var(--text);
    font-family: -apple-system, system-ui, 'Segoe UI', sans-serif;
    font-size: 15px;
    line-height: 1.4;
    padding: 12px;
    min-height: 100vh;
  }

  .page { max-width: 440px; margin: auto; display: flex; flex-direction: column; gap: 10px; }

  /* ── TOP BAR ── */
  .topbar {
    display: flex; align-items: center; justify-content: space-between;
    padding: 6px 0 10px;
  }
  .topbar-left h1 { font-size: 18px; font-weight: 600; letter-spacing: -0.02em; }
  .topbar-left .clock { font-size: 12px; color: var(--muted); margin-top: 2px; font-variant-numeric: tabular-nums; }

  /* ── CARDS ── */
  .card {
    background: var(--surface);
    border: 0.5px solid var(--border);
    border-radius: 14px;
    padding: 14px 16px;
  }
  .card.highlight { border-color: var(--blue-bd); }

  .card-header {
    display: flex; align-items: center; gap: 7px;
    margin-bottom: 12px;
  }
  .card-header svg { flex-shrink: 0; opacity: 0.45; }
  .card-header h2 {
    font-size: 11px; font-weight: 600; color: var(--muted);
    text-transform: uppercase; letter-spacing: .07em;
  }
  .card-header .chip {
    margin-left: auto;
    font-size: 11px; font-weight: 600;
    padding: 2px 8px; border-radius: 20px;
    background: var(--blue-bg); color: var(--blue); border: 0.5px solid var(--blue-bd);
  }

  /* ── BADGES ── */
  .badge {
    font-size: 11px; font-weight: 700; padding: 3px 9px;
    border-radius: 20px; letter-spacing: .05em; text-transform: uppercase;
  }
  .badge.ok     { background: var(--green-bg);  color: var(--green);  border: 0.5px solid var(--green-bd); }
  .badge.err    { background: var(--red-bg);    color: var(--red);    border: 0.5px solid var(--red-bd); }
  .badge.warn   { background: var(--yellow-bg); color: var(--yellow); border: 0.5px solid var(--yellow-bd); }
  .badge.off    { background: var(--surface2);  color: var(--dim);    border: 0.5px solid var(--border-s); }

  /* ── BUTTONS ── */
  .btn {
    width: 100%; border: none; border-radius: 10px;
    font-size: 15px; font-weight: 600; cursor: pointer;
    display: flex; align-items: center; justify-content: center; gap: 7px;
    transition: opacity .15s, transform .1s;
    -webkit-tap-highlight-color: transparent;
  }
  .btn:active { transform: scale(0.97); opacity: 0.85; }
  .btn svg { flex-shrink: 0; }

  .btn-capture {
    background: var(--blue); color: #fff;
    padding: 18px; font-size: 19px; font-weight: 700;
  }
  .btn-outline {
    background: var(--surface2); color: var(--text);
    border: 0.5px solid var(--border-s);
    padding: 12px; font-size: 14px;
  }
  .btn-outline.btn-danger  { color: var(--red);    background: var(--red-bg);    border-color: var(--red-bd); }
  .btn-outline.btn-success { color: var(--green);  background: var(--green-bg);  border-color: var(--green-bd); }
  .btn-outline.btn-purple  { color: var(--purple); background: var(--purple-bg); border-color: var(--purple-bd); }

  .btn-row { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 10px; }

  /* ── METRIC TILES ── */
  .tiles { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .tile {
    background: var(--surface2); border-radius: 10px; padding: 10px 12px;
    border: 0.5px solid var(--border);
  }
  .tile.wide { grid-column: span 2; }
  .tile .tlabel {
    font-size: 10px; font-weight: 600; color: var(--muted);
    text-transform: uppercase; letter-spacing: .06em; margin-bottom: 5px;
  }
  .tile .tvalue {
    font-size: 22px; font-weight: 500;
    font-variant-numeric: tabular-nums; letter-spacing: -0.01em;
    color: var(--text);
  }
  .tile .tunit { font-size: 13px; font-weight: 400; color: var(--muted); margin-left: 2px; }
  .tile .tvalue.c-blue   { color: var(--blue); }
  .tile .tvalue.c-green  { color: var(--green); }
  .tile .tvalue.c-yellow { color: var(--yellow); }
  .tile .tvalue.c-red    { color: var(--red); }
  .tile .trate { font-size: 14px; font-weight: 500; color: var(--text); word-break: break-all; line-height: 1.3; }

  /* ── STATUS ROWS ── */
  .srow {
    display: flex; align-items: center; justify-content: space-between;
    padding: 9px 0; border-bottom: 0.5px solid var(--border);
  }
  .srow:last-child { border-bottom: none; }
  .srow .slabel {
    display: flex; align-items: center; gap: 7px;
    font-size: 14px; color: var(--muted);
  }
  .srow .slabel svg { opacity: 0.5; flex-shrink: 0; }
  .srow .sval { font-size: 16px; font-weight: 500; font-variant-numeric: tabular-nums; }

  /* ── GPS ROWS ── */
  .grow {
    display: flex; align-items: baseline; justify-content: space-between;
    padding: 7px 0; border-bottom: 0.5px solid var(--border);
  }
  .grow:last-of-type { border-bottom: none; }
  .grow .glabel { font-size: 13px; color: var(--muted); }
  .grow .gvalue { font-size: 14px; font-variant-numeric: tabular-nums; color: var(--text); }

  /* ── PEER ROWS ── */
  .peer-row {
    display: flex; align-items: flex-start; justify-content: space-between;
    padding: 8px 0; border-bottom: 0.5px solid var(--border); gap: 8px;
  }
  .peer-row:last-child { border-bottom: none; }
  .peer-ip   { font-size: 13px; font-weight: 600; color: var(--blue); font-variant-numeric: tabular-nums; }
  .peer-coords { font-size: 12px; color: var(--muted); text-align: right; line-height: 1.5; }
  .peer-coords small { color: var(--dim); font-size: 11px; }
  .no-peers  { font-size: 13px; color: var(--dim); padding: 4px 0; }

  /* ── DIVIDER ── */
  .hdivider { height: 0.5px; background: var(--border); margin: 10px 0; }

  /* ── FOOTER ── */
  .footer { text-align: center; font-size: 11px; color: var(--dim); padding: 10px 0 6px; }
</style>
</head>

<body>
<div class="page">

<div class="topbar">
  <div class="topbar-left">
    <h1>Mesh Range Test</h1>
    <div class="clock">$SYSTEM_CURRENT_TIME</div>
  </div>
  <span class="badge $MESHBADGE">$MESHSTATE</span>
</div>

<div class="card highlight">
  <div class="card-header">
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M6.3 6.3A8 8 0 1 0 17.7 17.7"/><path d="M3 12H1M23 12h-2M12 3V1M12 23v-2"/></svg>
    <h2>Data capture</h2>
    <span class="chip">$COUNT saved</span>
  </div>
  <form id="capture-form" onsubmit="handleAsyncSubmit(event,'capture-form','btn-capture-id','Saving...')">
    <input type="hidden" name="run" value="1">
    <input type="hidden" id="lat" name="lat">
    <input type="hidden" id="lon" name="lon">
    <input type="hidden" id="acc" name="acc">
    <input type="hidden" id="capture-form-time" name="phone_time">
    <button type="submit" id="btn-capture-id" class="btn btn-capture">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 5v14M5 12l7 7 7-7"/></svg>
      Capture measurement
    </button>
  </form>
</div>

<div class="card">
  <div class="card-header">
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/></svg>
    <h2>RF link</h2>
  </div>
  <div class="tiles">
    <div class="tile">
      <div class="tlabel">RSSI</div>
      <div class="tvalue c-blue">$RSSI <span class="tunit">dBm</span></div>
    </div>
    <div class="tile">
      <div class="tlabel">SNR</div>
      <div class="tvalue">$SNR <span class="tunit">dB</span></div>
    </div>
    <div class="tile">
      <div class="tlabel">Noise floor</div>
      <div class="tvalue">$NOISE <span class="tunit">dBm</span></div>
    </div>
    <div class="tile">
      <div class="tlabel">Ch. busy</div>
      <div class="tvalue c-yellow">$BUSYPCT <span class="tunit">%</span></div>
    </div>
    <div class="tile">
      <div class="tlabel">Signal avg</div>
      <div class="tvalue">$AVG <span class="tunit">dBm</span></div>
    </div>
    <div class="tile">
      <div class="tlabel">ACK signal</div>
      <div class="tvalue">$ACK <span class="tunit">dBm</span></div>
    </div>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>
    <h2>PHY / mesh</h2>
  </div>
  <div class="tiles">
    <div class="tile wide">
      <div class="tlabel">TX rate</div>
      <div class="trate">$TXRATE</div>
    </div>
    <div class="tile wide">
      <div class="tlabel">RX rate</div>
      <div class="trate">$RXRATE</div>
    </div>
    <div class="tile">
      <div class="tlabel">TX MCS</div>
      <div class="tvalue">$TXMCS</div>
    </div>
    <div class="tile">
      <div class="tlabel">RX MCS</div>
      <div class="tvalue">$RXMCS</div>
    </div>
    <div class="tile">
      <div class="tlabel">Retries</div>
      <div class="tvalue c-yellow">$RETRIES</div>
    </div>
    <div class="tile">
      <div class="tlabel">Failed</div>
      <div class="tvalue c-red">$FAILED</div>
    </div>
    <div class="tile">
      <div class="tlabel">Airtime metric</div>
      <div class="tvalue">$AIRTIME</div>
    </div>
    <div class="tile">
      <div class="tlabel">Connected</div>
      <div class="tvalue">$CONNECTED <span class="tunit">s</span></div>
    </div>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="10" r="3"/><path d="M12 2a8 8 0 0 1 8 8c0 5.25-8 13-8 13S4 15.25 4 10a8 8 0 0 1 8-8z"/></svg>
    <h2>GPS</h2>
  </div>
  <div class="grow">
    <span class="glabel">Status</span>
    <span id="gps_status" class="gvalue" style="color:var(--muted)">Waiting...</span>
  </div>
  <div class="grow">
    <span class="glabel">Accuracy</span>
    <span class="gvalue"><span id="gps_acc">$ACC</span> m</span>
  </div>
  <div class="grow">
    <span class="glabel">Lat</span>
    <span id="gps_lat" class="gvalue">$LAT</span>
  </div>
  <div class="grow">
    <span class="glabel">Lon</span>
    <span id="gps_lon" class="gvalue">$LON</span>
  </div>
  <form id="share-form" onsubmit="handleAsyncSubmit(event,'share-form','btn-share-id','Sharing...')" style="margin-top:12px">
    <input type="hidden" name="save_pos" value="1">
    <input type="hidden" id="lat_pos" name="lat">
    <input type="hidden" id="lon_pos" name="lon">
    <input type="hidden" id="acc_pos" name="acc">
    <input type="hidden" id="share-form-time" name="phone_time">
    <button type="submit" id="btn-share-id" class="btn btn-outline btn-purple">
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.59 13.51l6.83 3.98M15.41 6.51l-6.82 3.98"/></svg>
      Save & share my position
    </button>
  </form>
</div>

<div class="card">
  <div class="card-header">
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="5" r="3"/><circle cx="5" cy="19" r="3"/><circle cx="19" cy="19" r="3"/><path d="M12 8v3M7.07 17.07l-1.9-1.9M16.93 17.07l1.9-1.9M5 16V12a7 7 0 0 1 14 0v4"/></svg>
    <h2>Remote nodes</h2>
  </div>
  ${REMOTE_NODES_HTML:-<div class='no-peers'>No remote location data available.</div>}
</div>

<div class="card">
  <div class="card-header">
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>
    <h2>System status</h2>
  </div>

  <div class="srow">
    <span class="slabel">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/></svg>
      Wi-Fi mesh
    </span>
    <span class="badge $MESHBADGE">$MESHSTATE</span>
  </div>
  <div class="srow">
    <span class="slabel">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
      Peers
    </span>
    <span class="sval">$PEERS</span>
  </div>

  <div class="hdivider"></div>

  <div class="srow">
    <span class="slabel">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>
      LoRa ($LORA_DEV)
    </span>
    <span class="badge $LORA_SERIAL_BADGE">$LORA_SERIAL_STATE</span>
  </div>
  <div class="srow">
    <span class="slabel">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="7" width="20" height="15" rx="2"/><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/><line x1="12" y1="12" x2="12" y2="16"/><line x1="10" y1="14" x2="14" y2="14"/></svg>
      TCP :$LORA_PORT
    </span>
    <span class="badge $LORA_TCP_BADGE">$LORA_TCP_STATE</span>
  </div>

  <div class="btn-row">
    <form id="toggle-form" onsubmit="handleAsyncSubmit(event,'toggle-form','btn-toggle-id','Applying...')">
      <input type="hidden" name="mesh_toggle" value="1">
      <input type="hidden" id="toggle-form-time" name="phone_time">
      <button type="submit" id="btn-toggle-id" class="btn btn-outline $MESHBTNCLASS" style="width:100%">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/></svg>
        $MESHLABEL
      </button>
    </form>
    <form id="refresh-form" onsubmit="handleAsyncSubmit(event,'refresh-form','btn-refresh-id','...') style="flex:1">
      <input type="hidden" id="refresh-form-time" name="phone_time">
      <button type="submit" id="btn-refresh-id" class="btn btn-outline" style="width:100%">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
        Refresh
      </button>
    </form>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
    <h2>Traffic</h2>
  </div>
  <div class="tiles">
    <div class="tile">
      <div class="tlabel">TX bytes</div>
      <div class="tvalue" style="font-size:16px">$TXBYTES</div>
    </div>
    <div class="tile">
      <div class="tlabel">RX bytes</div>
      <div class="tvalue" style="font-size:16px">$RXBYTES</div>
    </div>
    <div class="tile">
      <div class="tlabel">TX packets</div>
      <div class="tvalue" style="font-size:16px">$TXPKTS</div>
    </div>
    <div class="tile">
      <div class="tlabel">RX packets</div>
      <div class="tvalue" style="font-size:16px">$RXPKTS</div>
    </div>
    <div class="tile wide">
      <div class="tlabel">RX drop misc</div>
      <div class="tvalue c-yellow">$RXDROP</div>
    </div>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
    <h2>Tools</h2>
  </div>
  <div class="btn-row">
    <button id="btn-download-id" onclick="triggerSecureDownload()" class="btn btn-outline btn-success">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
      Download CSV
    </button>
    <form id="clear-form" onsubmit="handleAsyncSubmit(event,'clear-form','btn-clear-id','Clearing...')">
      <input type="hidden" name="clear" value="1">
      <button type="submit" id="btn-clear-id" class="btn btn-outline btn-danger" style="width:100%">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg>
        Clear log
      </button>
    </form>
  </div>
</div>

<div class="footer">/www/data/mesh_test_log.csv</div>

</div><script>
function getFormattedPhoneTime() {
  let d = new Date(), p = n => n < 10 ? '0'+n : n;
  return d.getFullYear()+'-'+p(d.getMonth()+1)+'-'+p(d.getDate())+' '+
         p(d.getHours())+':'+p(d.getMinutes())+':'+p(d.getSeconds());
}

function updateLocation() {
  if (!navigator.geolocation) return;
  navigator.geolocation.getCurrentPosition(
    function(pos) {
      let lat = pos.coords.latitude, lon = pos.coords.longitude, acc = pos.coords.accuracy;
      document.getElementById('lat').value = lat;
      document.getElementById('lon').value = lon;
      document.getElementById('acc').value = acc;
      if (document.getElementById('lat_pos')) {
        document.getElementById('lat_pos').value = lat;
        document.getElementById('lon_pos').value = lon;
        document.getElementById('acc_pos').value = acc;
      }
      document.getElementById('gps_status').textContent = 'GPS OK';
      document.getElementById('gps_status').style.color = 'var(--green)';
      document.getElementById('gps_lat').textContent = lat.toFixed(6);
      document.getElementById('gps_lon').textContent = lon.toFixed(6);
      document.getElementById('gps_acc').textContent = Math.round(acc);
    },
    function() {
      document.getElementById('gps_status').textContent = 'GPS error';
      document.getElementById('gps_status').style.color = 'var(--red)';
    },
    { enableHighAccuracy: true, timeout: 5000 }
  );
}

function handleAsyncSubmit(event, formId, buttonId, loadingText) {
  event.preventDefault();
  let timeInput = document.getElementById(formId + '-time');
  if (timeInput) timeInput.value = getFormattedPhoneTime();
  
  let btn = document.getElementById(buttonId);
  let originalValue = btn.textContent;
  btn.textContent = loadingText;
  btn.disabled = true;
  btn.style.opacity = '0.6';
  
  let form = document.getElementById(formId);
  let searchParams = new URLSearchParams(new FormData(form));
  fetch('/cgi-bin/meshtest.sh', { method: 'POST', body: searchParams })
    .then(() => { setTimeout(() => window.location.reload(), 800); })
    .catch(() => {
      btn.textContent = originalValue;
      btn.disabled = false;
      btn.style.opacity = '1';
      alert('Router communication error. Please try again.');
    });
}

function triggerSecureDownload() {
  let btn = document.getElementById('btn-download-id');
  let orig = btn.textContent;
  btn.textContent = 'Downloading...';
  btn.disabled = true;
  fetch('/data/mesh_test_log.csv')
    .then(r => { if (!r.ok) throw new Error(); return r.blob(); })
    .then(blob => {
      let url = URL.createObjectURL(blob);
      let a = document.createElement('a');
      a.href = url; a.download = 'mesh_test_log.csv';
      document.body.appendChild(a); a.click(); a.remove();
      URL.revokeObjectURL(url);
      btn.textContent = orig; btn.disabled = false;
    })
    .catch(() => {
      alert('CSV file not found. Capture data first.');
      btn.textContent = orig; btn.disabled = false;
    });
}

window.onload = function() {
  updateLocation();
  setInterval(updateLocation, 5000);
};
</script>
</body>
</html>
HTMLEOF