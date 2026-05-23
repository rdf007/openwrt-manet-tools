import sys
import argparse
import pandas as pd
import matplotlib.pyplot as plt

def parse_arguments():
    parser = argparse.ArgumentParser(description="Analyze and plot OpenWrt Mesh Range Test data.")
    parser.add_argument("csvfile", help="Path to the input CSV file")
    return parser.parse_args()

def calculate_throughput(df, byte_col, target_col):
    if byte_col in df.columns and "epoch" in df.columns:
        df[target_col] = (df[byte_col].diff() * 8) / df["epoch"].diff() / 1e6
        df.loc[df[target_col] < 0, target_col] = None
    return df

def process_data(csvfile):
    df = pd.read_csv(csvfile)
    numeric_cols = [
        "distance_m", "rssi", "snr", "airtime", "txmcs", "rxmcs",
        "busy_pct", "epoch", "tx_bytes", "rx_bytes", "rx_drop_misc"
    ]
    cols_to_convert = [c for c in numeric_cols if c in df.columns]
    df[cols_to_convert] = df[cols_to_convert].apply(pd.to_numeric, errors="coerce")

    for col in ["txrate", "rxrate"]:
        if col in df.columns:
            df[f"{col}_mbps"] = df[col].astype(str).str.extract(r"([0-9.]+)").astype(float)

    df = df.dropna(subset=["distance_m"])
    if "epoch" in df.columns:
        df = df.sort_values("epoch")

    df = calculate_throughput(df, "tx_bytes", "tx_mbps")
    df = calculate_throughput(df, "rx_bytes", "rx_mbps")

    if "rx_drop_misc" in df.columns:
        df["rx_drop_delta"] = df["rx_drop_misc"].diff()
        df.loc[df["rx_drop_delta"] < 0, "rx_drop_delta"] = None

    grouped = df.groupby("distance_m")
    df_avg = grouped.mean(numeric_only=True).reset_index()
    df_std = grouped.std(numeric_only=True).reset_index()
    df_count = grouped.size().reset_index(name="samples")
    summary = df_avg.merge(df_std, on="distance_m", suffixes=("", "_std")).merge(df_count, on="distance_m")
    return summary.sort_values("distance_m")

def plot_results(summary, output_png):
    plt.rcParams.update({"font.size": 13})
    fig, axs = plt.subplots(4, 2, figsize=(18, 17), sharex=True)
    fig.suptitle("OpenWrt Mesh Range Test Analysis", fontsize=22)

    def plot_err(ax, col, label, unit):
        if col in summary.columns:
            ax.errorbar(summary["distance_m"], summary[col], yerr=summary.get(f"{col}_std"), marker='o', capsize=5)
            ax.set_title(f"{label} vs Distance")
            ax.set_ylabel(f"{label} ({unit})")
            ax.grid()
        else:
            ax.text(0.5, 0.5, f"{label} data missing", ha='center')

    plot_err(axs[0, 0], "rssi", "RSSI", "dBm")    # 1. RSSI
    plot_err(axs[0, 1], "snr", "SNR", "dB")       # 2. SNR
    plot_err(axs[1, 0], "airtime", "Airtime", "units") # 3. Airtime

    # 4. MCS Plot
    if "txmcs" in summary.columns:
        axs[1, 1].plot(summary["distance_m"], summary["txmcs"], marker='o', label="TX MCS")
        axs[1, 1].plot(summary["distance_m"], summary["rxmcs"], marker='o', label="RX MCS")
        axs[1, 1].set_ylim(0, 12)
        axs[1, 1].set_title("MCS vs Distance")
        axs[1, 1].legend()
        axs[1, 1].grid()

    # 5. Throughput
    if "tx_mbps" in summary.columns:
        axs[2, 0].plot(summary["distance_m"], summary["tx_mbps"], marker='o', label="TX")
        axs[2, 0].plot(summary["distance_m"], summary["rx_mbps"], marker='o', label="RX")
        axs[2, 0].set_title("Throughput vs Distance")
        axs[2, 0].set_ylabel("Mbps")
        axs[2, 0].set_ylim(bottom=0)
        axs[2, 0].legend()
        axs[2, 0].grid()

    # 6. Channel Busy
    if "busy_pct" in summary.columns:
        axs[2, 1].plot(summary["distance_m"], summary["busy_pct"], marker='o')
        axs[2, 1].set_title("Channel Busy vs Distance")
        axs[2, 1].set_ylabel("Busy (%)")
        axs[2, 1].grid()

    # 7. RX Drop
    if "rx_drop_delta" in summary.columns:
        axs[3, 0].plot(summary["distance_m"], summary["rx_drop_delta"], marker='o')
        axs[3, 0].set_title("RX Drop Delta vs Distance")
        axs[3, 0].set_ylabel("Dropped Frames")
        axs[3, 0].grid()
    else:
        axs[3, 0].axis("off")
    axs[3, 0].set_xlabel("Distance (m)")

    # 8. PHY Rate
    if "txrate_mbps" in summary.columns:
        axs[3, 1].plot(summary["distance_m"], summary["txrate_mbps"], marker='o', label="TX Rate")
        axs[3, 1].plot(summary["distance_m"], summary["rxrate_mbps"], marker='o', label="RX Rate")
        axs[3, 1].set_title("PHY Rate vs Distance")
        axs[3, 1].set_ylabel("Mbps")
        axs[3, 1].legend()
        axs[3, 1].grid()
    axs[3, 1].set_xlabel("Distance (m)")

    plt.tight_layout()
    plt.savefig(output_png, dpi=300, bbox_inches="tight")
    print(f"\nSaved plot: {output_png}")
    plt.show()

def main():
    args = parse_arguments()
    try:
        print(f"\nLoading CSV: {args.csvfile}")
        summary = process_data(args.csvfile)
        
        print("\nAveraged Results:\n")
        show_cols = ["distance_m", "samples", "rssi", "snr", "tx_mbps", "rx_mbps"]
        print(summary[[c for c in show_cols if c in summary.columns]])
        
        plot_results(summary, args.csvfile.replace(".csv", ".png"))
    except Exception as e:
        print(f"Error processing data: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()