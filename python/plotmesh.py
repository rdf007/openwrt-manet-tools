import sys
import pandas as pd
import matplotlib.pyplot as plt

# =========================
# INPUT ARGUMENT
# =========================

if len(sys.argv) < 2:
    print("Usage:")
    print("python3 plotmesh.py <csvfile>")
    sys.exit(1)

csvfile = sys.argv[1]

print(f"Loading CSV: {csvfile}")

# =========================
# LOAD DATA
# =========================

df = pd.read_csv(csvfile)

# =========================
# NUMERIC CONVERSION
# =========================

numeric_cols = [
    "distance_m",
    "rssi",
    "snr",
    "airtime",
    "retries",
    "txmcs",
    "rxmcs",
    "busy_pct"
]

for col in numeric_cols:
    df[col] = pd.to_numeric(df[col], errors="coerce")

# =========================
# REMOVE INVALID ROWS
# =========================

df = df.dropna(subset=["distance_m"])

# =========================
# GROUP BY DISTANCE
# Averages all samples for each distance
# =========================

df_avg = (
    df.groupby("distance_m")
    .mean(numeric_only=True)
    .reset_index()
    .sort_values("distance_m")
)

print("\nAveraged Results:\n")
print(df_avg)

# =========================
# PLOT 1: RSSI vs Distance
# =========================

plt.figure()

plt.plot(
    df_avg["distance_m"],
    df_avg["rssi"],
    marker='o'
)

plt.xlabel("Distance (m)")
plt.ylabel("RSSI (dBm)")
plt.title("RSSI vs Distance")
plt.grid()

# =========================
# PLOT 2: SNR vs Distance
# =========================

plt.figure()

plt.plot(
    df_avg["distance_m"],
    df_avg["snr"],
    marker='o'
)

plt.xlabel("Distance (m)")
plt.ylabel("SNR (dB)")
plt.title("SNR vs Distance")
plt.grid()

# =========================
# PLOT 3: Airtime vs Distance
# =========================

plt.figure()

plt.plot(
    df_avg["distance_m"],
    df_avg["airtime"],
    marker='o'
)

plt.xlabel("Distance (m)")
plt.ylabel("Airtime Metric")
plt.title("Airtime vs Distance")
plt.grid()

# =========================
# PLOT 4: MCS vs Distance
# =========================

plt.figure()

plt.plot(
    df_avg["distance_m"],
    df_avg["txmcs"],
    marker='o',
    label="TX MCS"
)

plt.plot(
    df_avg["distance_m"],
    df_avg["rxmcs"],
    marker='o',
    label="RX MCS"
)

plt.xlabel("Distance (m)")
plt.ylabel("MCS Index")
plt.title("MCS vs Distance")
plt.legend()
plt.grid()

# =========================
# PLOT 5: Retries vs Distance
# =========================

plt.figure()

plt.plot(
    df_avg["distance_m"],
    df_avg["retries"],
    marker='o'
)

plt.xlabel("Distance (m)")
plt.ylabel("Retries")
plt.title("Retries vs Distance")
plt.grid()

# =========================
# PLOT 6: Channel Busy vs Distance
# =========================

plt.figure()

plt.plot(
    df_avg["distance_m"],
    df_avg["busy_pct"],
    marker='o'
)

plt.xlabel("Distance (m)")
plt.ylabel("Channel Busy (%)")
plt.title("Channel Busy vs Distance")
plt.grid()

# =========================
# SHOW ALL
# =========================

plt.show()