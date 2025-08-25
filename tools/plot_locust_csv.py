import sys, pathlib
import pandas as pd
import matplotlib.pyplot as plt

if len(sys.argv) < 2:
    print("usage: python tools/plot_locust_csv.py <stats_history_csv>")
    sys.exit(1)

csv_path = pathlib.Path(sys.argv[1])
if not csv_path.exists():
    print(f"[ERR] file not found: {csv_path}")
    sys.exit(2)

df = pd.read_csv(csv_path)

# pick time column
time_col = "Timestamp" if "Timestamp" in df.columns else df.columns[0]

# normalize column names (locust 버전 차이 대비)
def pick(*names):
    for n in names:
        if n in df.columns: return n
    return None

rps_col = pick("Requests/s", "Requests/s ")
p95_col = pick("95%ile", "95%")

# plot RPS
plt.figure()
df.plot(x=time_col, y=rps_col)
plt.title("Requests per second")
plt.xticks(rotation=45, ha="right")
plt.tight_layout()
out_rps = csv_path.with_suffix(".rps.png")
plt.savefig(out_rps)

# plot latency (prefer p95, fallback to Median)
lat_col = p95_col or pick("Median Response Time", "Median", "Average Response Time")
if lat_col:
    plt.figure()
    df.plot(x=time_col, y=lat_col)
    ttl = f"Response time ({lat_col})"
    plt.title(ttl)
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    out_lat = csv_path.with_suffix(".latency.png")
    plt.savefig(out_lat)
    print(f"[OK] Saved: {out_rps} , {out_lat}")
else:
    print(f"[OK] Saved: {out_rps} (no latency column found)")
