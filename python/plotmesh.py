import pandas as pd
import matplotlib.pyplot as plt

# =========================
# LOAD DATA
# =========================
df = pd.read_csv("mesh_test_log.csv")

# garantir tipos numéricos
numeric_cols = [
    "rssi","snr","airtime","retries","txmcs","rxmcs","busy_pct"
]

for col in numeric_cols:
    df[col] = pd.to_numeric(df[col], errors="coerce")

# =========================
# GROUP BY DISTANCE (média)
# =========================
df_avg = df.groupby("distance").mean(numeric_only=True).reset_index()

print(df_avg)

# =========================
# PLOT 1: RSSI vs Distance
# =========================
plt.figure()
plt.plot(df_avg["distance"], df_avg["rssi"], marker='o')
plt.xlabel("Distance (m)")
plt.ylabel("RSSI (dBm)")
plt.title("RSSI vs Distance")
plt.grid()

# =========================
# PLOT 2: SNR vs Distance
# =========================
plt.figure()
plt.plot(df_avg["distance"], df_avg["snr"], marker='o')
plt.xlabel("Distance (m)")
plt.ylabel("SNR (dB)")
plt.title("SNR vs Distance")
plt.grid()

# =========================
# PLOT 3: Airtime vs Distance
# =========================
plt.figure()
plt.plot(df_avg["distance"], df_avg["airtime"], marker='o')
plt.xlabel("Distance (m)")
plt.ylabel("Airtime Metric")
plt.title("Airtime vs Distance")
plt.grid()

# =========================
# PLOT 4: MCS vs Distance
# =========================
plt.figure()
plt.plot(df_avg["distance"], df_avg["txmcs"], marker='o', label="TX MCS")
plt.plot(df_avg["distance"], df_avg["rxmcs"], marker='o', label="RX MCS")
plt.xlabel("Distance (m)")
plt.ylabel("MCS Index")
plt.title("MCS vs Distance")
plt.legend()
plt.grid()

# =========================
# PLOT 5: Retries vs Distance
# =========================
plt.figure()
plt.plot(df_avg["distance"], df_avg["retries"], marker='o')
plt.xlabel("Distance (m)")
plt.ylabel("Retries")
plt.title("Retries vs Distance")
plt.grid()

# =========================
# PLOT 6: Channel Busy vs Distance
# =========================
plt.figure()
plt.plot(df_avg["distance"], df_avg["busy_pct"], marker='o')
plt.xlabel("Distance (m)")
plt.ylabel("Channel Busy (%)")
plt.title("Channel Busy vs Distance")
plt.grid()

# =========================
# SHOW ALL
# =========================
plt.show()