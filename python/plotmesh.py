import sys
import argparse
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import folium

def parse_arguments():
    parser = argparse.ArgumentParser(description="Analyze and plot OpenWrt Mesh Range Test data.")
    parser.add_argument("csvfile", help="Path to the input CSV file")
    return parser.parse_args()

def calculate_throughput(df, byte_col, target_col):
    if byte_col in df.columns and "epoch" in df.columns:
        dt = df["epoch"].diff()
        db = df[byte_col].diff()
        # Avoid division by zero if multiple samples occur at the same timestamp
        # Also handle counter resets (db < 0)
        df[target_col] = np.where((dt > 0) & (db >= 0), (db * 8) / dt / 1e6, np.nan)
        df.loc[df[target_col] < 0, target_col] = None
    return df

def get_rssi_color(rssi):
    """Returns color based on RSSI quality."""
    if pd.isna(rssi):
        return "gray"
    if rssi > -60:
        return "green"
    elif rssi > -67:
        return "yellow"
    elif rssi > -75:
        return "orange"
    else:
        return "red"

def generate_map(df, output_html):
    """Generates an interactive Folium map with trajectory and metrics."""
    # Filter rows with valid GPS
    df_gps = df.dropna(subset=["lat", "lon"]).copy()
    if df_gps.empty:
        print("No valid GPS data found for mapping.")
        return

    # Sort by epoch for trajectory
    if "epoch" in df_gps.columns:
        df_gps = df_gps.sort_values("epoch")

    # Calculate stable NODE2 position using median
    peer_data = df_gps.dropna(subset=["peer_lat", "peer_lon"])
    peer_pos = None
    if not peer_data.empty:
        peer_pos = (peer_data["peer_lat"].median(), peer_data["peer_lon"].median())
    
    # Center map on NODE2 if available, otherwise on NODE1 mean
    if peer_pos:
        center_lat, center_lon = peer_pos
    else:
        center_lat, center_lon = df_gps["lat"].mean(), df_gps["lon"].mean()

    m = folium.Map(location=[center_lat, center_lon], zoom_start=17, control_scale=True, tiles=None)
    folium.TileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', 
                     attr='Esri', name='Satellite (Esri)').add_to(m)
    folium.TileLayer('OpenStreetMap', name='Street Map').add_to(m)

    if peer_pos:
        # Add NODE2 Marker
        folium.Marker(
            location=peer_pos,
            popup=f"<b>NODE2 (Static Peer)</b><br>Lat: {peer_pos[0]:.6f}<br>Lon: {peer_pos[1]:.6f}",
            icon=folium.Icon(color="blue", icon="broadcast-tower", prefix='fa')
        ).add_to(m)

        # Dynamic concentric distance circles
        max_dist = df_gps['calculated_dist'].max()
        if max_dist > 0:
            radii = [int(max_dist * p) for p in [0.2, 0.4, 0.6, 0.8, 1.0]]
        else:
            radii = [100, 200, 300, 500]

        for dist in radii:
            folium.Circle(
                location=peer_pos,
                radius=dist,
                color="black",
                weight=2,
                fill=False,
                dash_array='5, 10',
                opacity=0.5
            ).add_to(m)
            # Add distance label
            folium.map.Marker(
                [peer_pos[0], peer_pos[1] + (dist / 111320)], 
                icon=folium.features.DivIcon(
                    icon_size=(150,36),
                    icon_anchor=(0,0),
                    html=f'<div style="font-size: 10pt; color: gray;">{dist}m</div>',
                )
            ).add_to(m)

    # Add thin trail line
    folium.PolyLine(df_gps[["lat", "lon"]].values, color="gray", weight=1, opacity=0.4).add_to(m)

    # Find Worst RSSI Sample
    worst_row = df_gps.loc[df_gps["rssi"].idxmin()] if "rssi" in df_gps.columns else None

    # Calculate Effective Range (Max distance where RSSI >= -70)
    eff_df = df_gps[df_gps["rssi"] >= -70]
    effective_range_70 = eff_df["calculated_dist"].max() if not eff_df.empty else 0
    best_rssi = df_gps["rssi"].max()
    worst_rssi = df_gps["rssi"].min()

    def get_val(row, col, fmt="{:.1f}", default="-"):
        val = row.get(col)
        if pd.isna(val) or val is None: return default
        return fmt.format(val) if isinstance(val, (int, float, np.number)) else str(val)

    # Draw markers for NODE1
    for idx, (i, row) in enumerate(df_gps.iterrows(), 1):
        color = get_rssi_color(row.get("rssi"))
        
        # Build detailed popup content
        popup_content = f"""
        <div style="font-family: sans-serif; font-size: 12px; min-width: 180px;">
            <b style="font-size: 14px; color: #333;">NODE1 Sample</b><hr style="margin: 5px 0;">
            <b>Distance:</b> {get_val(row, 'calculated_dist')} m<br>
            <b>Time:</b> {row.get('time', '-')}<br>
            <b>Epoch:</b> {row.get('epoch', '-')}<br>
            <b>GPS Accuracy:</b> {get_val(row, 'accuracy_m')} m<br>
            <b>RSSI:</b> {get_val(row, 'rssi', '{:.0f}')} dBm<br>
            <b>SNR:</b> {get_val(row, 'snr', '{:.0f}')} dB<br>
        """
        if 'txmcs' in row: popup_content += f"<b>MCS (TX/RX):</b> {get_val(row, 'txmcs', '{:.0f}')} / {get_val(row, 'rxmcs', '{:.0f}')}<br>"
        if 'txrate_mbps' in row: popup_content += f"<b>PHY (TX/RX):</b> {get_val(row, 'txrate_mbps')} / {get_val(row, 'rxrate_mbps')} Mbps<br>"
        if 'tx_mbps' in row: popup_content += f"<b>Thr (TX/RX):</b> {get_val(row, 'tx_mbps', '{:.2f}')} / {get_val(row, 'rx_mbps', '{:.2f}')} Mbps<br>"
        if 'retries' in row: popup_content += f"<b>Retries/Failed:</b> {get_val(row, 'retries', '{:.0f}')} / {get_val(row, 'failed', '{:.0f}')}<br>"
        if 'airtime' in row: popup_content += f"<b>Airtime:</b> {get_val(row, 'airtime', '{:.0f}')}<br>"
        if 'busy_pct' in row: popup_content += f"<b>Busy:</b> {get_val(row, 'busy_pct', '{:.1f}')} %<br>"
        popup_content += "</div>"
        
        current_point = [row['lat'], row['lon']]
        
        # Circle Marker
        folium.CircleMarker(
            location=current_point,
            radius=7,
            color=color,
            fill=True,
            fill_color=color,
            fill_opacity=0.7,
            popup=folium.Popup(popup_content, max_width=300)
        ).add_to(m)

        dist_label = f"{idx} ({get_val(row, 'calculated_dist', '{:.0f}')}m)"
        # Label with sample number
        folium.map.Marker(
            current_point,
            icon=folium.features.DivIcon(
                icon_size=(100,20),
                icon_anchor=(0,0),
                html=f'<div style="font-size: 8pt; color: black; font-weight: bold; background: rgba(255,255,255,0.5); width: fit-content; padding: 1px 3px; border-radius: 3px;">{dist_label}</div>',
            )
        ).add_to(m)

    # Mark Worst RSSI Point
    if worst_row is not None:
        folium.Marker(
            location=[worst_row["lat"], worst_row["lon"]],
            popup=f"⚠ <b>Worst RSSI Point</b><br>RSSI: {worst_row['rssi']} dBm",
            icon=folium.Icon(color="darkred", icon="exclamation-triangle", prefix='fa')
        ).add_to(m)

    # RSSI Legend
    legend_html = '''
     <div style="position: fixed; bottom: 50px; left: 50px; width: 140px; border:2px solid grey; z-index:9999; 
     font-size:12px; background-color:white; opacity: 0.85; padding: 10px; border-radius: 5px;">
     <b>RSSI Quality</b><br>
     <i class="fa fa-circle" style="color:green"></i> &gt; -60 dBm<br>
     <i class="fa fa-circle" style="color:yellow"></i> &gt; -67 dBm<br>
     <i class="fa fa-circle" style="color:orange"></i> &gt; -75 dBm<br>
     <i class="fa fa-circle" style="color:red"></i> &le; -75 dBm
     </div>
     '''

    # Add layer control
    folium.LayerControl().add_to(m)
    m.get_root().html.add_child(folium.Element(legend_html))

    # Stats Box
    stats_html = f'''
     <div style="position: fixed; bottom: 20px; right: 10px; width: 180px; border:2px solid grey; z-index:9999; 
     font-size:12px; background-color:white; opacity: 0.85; padding: 10px; border-radius: 5px;">
     <b>Test Summary</b><br>
     Samples: {len(df_gps)}<br>
     Max Range: {df_gps['calculated_dist'].max():.0f} m<br>
     Effective Range (-70dBm): {effective_range_70:.0f} m<br><br>
     Best RSSI: {best_rssi:.0f} dBm<br>
     Worst RSSI: {worst_rssi:.0f} dBm<br>
     SNR Range: {df_gps['snr'].min():.0f} to {df_gps['snr'].max():.0f} dB
     </div>
    '''
    m.get_root().html.add_child(folium.Element(stats_html))

    m.save(output_html)
    print(f"Saved interactive map: {output_html}")

def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculates distance between two points in meters using Haversine formula."""
    if pd.isna([lat1, lon1, lat2, lon2]).any():
        return None
    R = 6371000  # Earth radius in meters
    phi1, phi2 = np.radians(lat1), np.radians(lat2)
    dphi = np.radians(lat2 - lat1)
    dlambda = np.radians(lon2 - lon1)
    a = np.sin(dphi/2)**2 + np.cos(phi1) * np.cos(phi2) * np.sin(dlambda/2)**2
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
    return R * c

def process_data(csvfile):
    df = pd.read_csv(csvfile)
    numeric_cols = [
        "lat", "lon", "peer_lat", "peer_lon", "rssi", "snr", "airtime", 
        "txmcs", "rxmcs", "busy_pct", "epoch", "tx_bytes", "rx_bytes", "rx_drop_misc"
    ]
    cols_to_convert = [c for c in numeric_cols if c in df.columns]
    df[cols_to_convert] = df[cols_to_convert].apply(pd.to_numeric, errors="coerce")

    # Calculate distance based on GPS coordinates
    df["calculated_dist"] = df.apply(lambda r: haversine_distance(r['lat'], r['lon'], r['peer_lat'], r['peer_lon']), axis=1)
    df = df.dropna(subset=["calculated_dist"])
    # Group into 10-meter bins for better trend analysis
    df["dist_group"] = (df["calculated_dist"] / 10).round() * 10

    for col in ["txrate", "rxrate"]:
        if col in df.columns:
            df[f"{col}_mbps"] = df[col].astype(str).str.extract(r"([0-9.]+)").astype(float)

    if "epoch" in df.columns:
        df = df.sort_values("epoch")

    df = calculate_throughput(df, "tx_bytes", "tx_mbps")
    df = calculate_throughput(df, "rx_bytes", "rx_mbps")

    if "rx_drop_misc" in df.columns:
        df["rx_drop_delta"] = df["rx_drop_misc"].diff()
        df.loc[df["rx_drop_delta"] < 0, "rx_drop_delta"] = None

    grouped = df.groupby("dist_group")
    df_avg = grouped.mean(numeric_only=True).reset_index()
    df_std = grouped.std(numeric_only=True).reset_index()
    df_count = grouped.size().reset_index(name="samples")
    summary = df_avg.merge(df_std, on="dist_group", suffixes=("", "_std")).merge(df_count, on="dist_group").fillna(0)
    return df, summary.sort_values("dist_group")

def plot_results(df, summary, output_png):
    plt.rcParams.update({"font.size": 13})
    fig, axs = plt.subplots(4, 2, figsize=(18, 17), sharex=True)
    fig.suptitle("OpenWrt Mesh Range Test Analysis", fontsize=22)

    def plot_err(ax, col, label, unit):
        if col in summary.columns and col in df.columns:
            # Plot raw samples in background
            ax.scatter(df["calculated_dist"], df[col], color='gray', alpha=0.5, s=25, label="Raw Samples")
            # Plot averaged trend
            ax.errorbar(summary["dist_group"], summary[col], yerr=summary.get(f"{col}_std"), 
                        marker='o', markersize=8, capsize=5, color='blue', label="Mean")
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
        axs[1, 1].plot(summary["dist_group"], summary["txmcs"], marker='o', label="TX MCS")
        axs[1, 1].plot(summary["dist_group"], summary["rxmcs"], marker='o', label="RX MCS")
        axs[1, 1].set_ylim(0, 12)
        axs[1, 1].set_title("MCS vs Distance")
        axs[1, 1].legend()
        axs[1, 1].grid()

    # 5. Throughput
    if "tx_mbps" in summary.columns:
        axs[2, 0].scatter(df["calculated_dist"], df["tx_mbps"], color='blue', alpha=0.3, s=20, label="TX Samples")
        axs[2, 0].scatter(df["calculated_dist"], df["rx_mbps"], color='green', alpha=0.3, s=20, label="RX Samples")
        axs[2, 0].plot(summary["dist_group"], summary["tx_mbps"], marker='o', label="TX Mean")
        axs[2, 0].plot(summary["dist_group"], summary["rx_mbps"], marker='o', label="RX Mean")
        axs[2, 0].set_title("Throughput vs Distance")
        axs[2, 0].set_ylabel("Mbps")
        axs[2, 0].set_ylim(bottom=0)
        axs[2, 0].legend()
        axs[2, 0].grid()

    # 6. Channel Busy
    if "busy_pct" in summary.columns:
        axs[2, 1].scatter(df["calculated_dist"], df["busy_pct"], color='gray', alpha=0.5, s=25)
        axs[2, 1].plot(summary["dist_group"], summary["busy_pct"], marker='o')
        axs[2, 1].set_title("Channel Busy vs Distance")
        axs[2, 1].set_ylabel("Busy (%)")
        axs[2, 1].grid()

    # 7. RX Drop
    if "rx_drop_delta" in summary.columns:
        axs[3, 0].scatter(df["calculated_dist"], df["rx_drop_delta"], color='gray', alpha=0.5, s=25)
        axs[3, 0].plot(summary["dist_group"], summary["rx_drop_delta"], marker='o')
        axs[3, 0].set_title("RX Drop Delta vs Distance")
        axs[3, 0].set_ylabel("Dropped Frames")
        axs[3, 0].grid()
    else:
        axs[3, 0].axis("off")
    axs[3, 0].set_xlabel("Calculated Distance (m)")

    # 8. PHY Rate
    if "txrate_mbps" in summary.columns:
        axs[3, 1].plot(summary["dist_group"], summary["txrate_mbps"], marker='o', label="TX Rate")
        axs[3, 1].plot(summary["dist_group"], summary["rxrate_mbps"], marker='o', label="RX Rate")
        axs[3, 1].set_title("PHY Rate vs Distance")
        axs[3, 1].set_ylabel("Mbps")
        axs[3, 1].legend()
        axs[3, 1].grid()
    axs[3, 1].set_xlabel("Calculated Distance (m)")

    plt.tight_layout()
    plt.savefig(output_png, dpi=300, bbox_inches="tight")
    print(f"\nSaved plot: {output_png}")
    plt.show()

def main():
    args = parse_arguments()
    try:
        print(f"\nLoading CSV: {args.csvfile}")
        df, summary = process_data(args.csvfile)
        
        print("\nAveraged Results:\n")
        show_cols = ["dist_group", "samples", "rssi", "snr", "tx_mbps", "rx_mbps"]
        print(summary[[c for c in show_cols if c in summary.columns]])
        
        plot_results(df, summary, args.csvfile.replace(".csv", ".png"))
        generate_map(df, args.csvfile.replace(".csv", "_map.html"))
    except Exception as e:
        print(f"Error processing data: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()