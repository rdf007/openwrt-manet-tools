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

print(f"\nLoading CSV: {csvfile}")

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
    "busy_pct",
    "lat",
    "lon",
    "accuracy_m"
]

for col in numeric_cols:

    if col in df.columns:

        df[col] = pd.to_numeric(
            df[col],
            errors="coerce"
        )

# =========================
# REMOVE INVALID DISTANCE
# =========================

df = df.dropna(subset=["distance_m"])

# =========================
# GROUP BY DISTANCE
# =========================

grouped = df.groupby("distance_m")

# =========================
# MEAN VALUES
# =========================

df_avg = grouped.mean(
    numeric_only=True
).reset_index()

# =========================
# STANDARD DEVIATION
# =========================

df_std = grouped.std(
    numeric_only=True
).reset_index()

# =========================
# SAMPLE COUNT
# =========================

df_count = grouped.size().reset_index(
    name="samples"
)

# =========================
# MERGE RESULTS
# =========================

summary = df_avg.merge(
    df_std,
    on="distance_m",
    suffixes=("", "_std")
)

summary = summary.merge(
    df_count,
    on="distance_m"
)

summary = summary.sort_values(
    "distance_m"
)

# =========================
# PRINT SUMMARY
# =========================

print("\nAveraged Results:\n")

cols_to_show = [
    "distance_m",
    "samples",
    "rssi",
    "rssi_std",
    "snr",
    "snr_std",
    "airtime",
    "airtime_std"
]

print(summary[cols_to_show])

# =========================
# GLOBAL FONT CONFIG
# =========================

plt.rcParams.update({
    "font.size": 13
})

# =========================
# CREATE FIGURE
# =========================

fig, axs = plt.subplots(
    3,
    2,
    figsize=(18, 13),
    sharex=True
)

fig.suptitle(
    "OpenWrt Mesh Range Test Analysis",
    fontsize=22
)

# =========================
# RSSI
# =========================

axs[0, 0].errorbar(
    summary["distance_m"],
    summary["rssi"],
    yerr=summary["rssi_std"],
    marker='o',
    capsize=5
)

axs[0, 0].set_title("RSSI vs Distance")
axs[0, 0].set_ylabel("RSSI (dBm)")
axs[0, 0].grid()

# =========================
# SNR
# =========================

axs[0, 1].errorbar(
    summary["distance_m"],
    summary["snr"],
    yerr=summary["snr_std"],
    marker='o',
    capsize=5
)

axs[0, 1].set_title("SNR vs Distance")
axs[0, 1].set_ylabel("SNR (dB)")
axs[0, 1].grid()

# =========================
# AIRTIME
# =========================

axs[1, 0].errorbar(
    summary["distance_m"],
    summary["airtime"],
    yerr=summary["airtime_std"],
    marker='o',
    capsize=5
)

axs[1, 0].set_title("Airtime vs Distance")
axs[1, 0].set_ylabel("Airtime")
axs[1, 0].grid()

# =========================
# MCS
# =========================

axs[1, 1].plot(
    summary["distance_m"],
    summary["txmcs"],
    marker='o',
    label="TX MCS"
)

axs[1, 1].plot(
    summary["distance_m"],
    summary["rxmcs"],
    marker='o',
    label="RX MCS"
)

axs[1, 1].set_title("MCS vs Distance")
axs[1, 1].set_ylabel("MCS")
axs[1, 1].legend(fontsize=12)
axs[1, 1].grid()

# =========================
# RETRIES
# =========================

axs[2, 0].plot(
    summary["distance_m"],
    summary["retries"],
    marker='o'
)

axs[2, 0].set_title("Retries vs Distance")
axs[2, 0].set_xlabel("Distance (m)")
axs[2, 0].set_ylabel("Retries")
axs[2, 0].grid()

# =========================
# CHANNEL BUSY
# =========================

axs[2, 1].plot(
    summary["distance_m"],
    summary["busy_pct"],
    marker='o'
)

axs[2, 1].set_title("Channel Busy vs Distance")
axs[2, 1].set_xlabel("Distance (m)")
axs[2, 1].set_ylabel("Busy (%)")
axs[2, 1].grid()

# =========================
# LAYOUT
# =========================

plt.tight_layout()

# =========================
# SAVE PNG
# =========================

output_png = csvfile.replace(".csv", ".png")

plt.savefig(
    output_png,
    dpi=300,
    bbox_inches="tight"
)

print(f"\nSaved plot: {output_png}")

# =========================
# SHOW
# =========================

plt.show()