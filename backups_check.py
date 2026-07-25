#!/usr/bin/env python3
# Kjores via systemd-timer PA Proxmox-hosten selv (ingen scp nodvendig, alt er
# lokalt): leser vzdump-mtider fra /var/lib/vz/dump/ og snapshot-tidspunkt for
# VM 101 (OPNsense) / VM 300 (Metasploitable) via pvesh, skriver backups.json,
# og pusher den inn i CT 203 sin status-mappe med "pct push".
import glob
import json
import os
import subprocess
import time


def snapshot_days_ago(vmid):
    out = subprocess.run(
        ["pvesh", "get", f"/nodes/proxy/qemu/{vmid}/snapshot", "--output-format", "json"],
        capture_output=True, text=True, check=True,
    )
    snaps = json.loads(out.stdout)
    times = [s["snaptime"] for s in snaps if "snaptime" in s]
    if not times:
        return "unknown"
    return str(round((time.time() - max(times)) / 86400, 1))


def last_vzdump_days_ago():
    files = glob.glob("/var/lib/vz/dump/*.tar.zst")
    if not files:
        return "unknown"
    newest = max(os.path.getmtime(f) for f in files)
    return str(round((time.time() - newest) / 86400, 1))


data = {
    "opnsense_snapshot_days_ago": snapshot_days_ago(101),
    "metasploitable_snapshot_days_ago": snapshot_days_ago(300),
    "last_vzdump_days_ago": last_vzdump_days_ago(),
    "last_checked": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}

with open("/root/backups.json", "w") as f:
    json.dump(data, f)

subprocess.run(["pct", "push", "203", "/root/backups.json", "/opt/homepage/status/backups.json"], check=True)
os.remove("/root/backups.json")
