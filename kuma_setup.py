import os
import json
from uptime_kuma_api import UptimeKumaApi, MonitorType

KUMA_URL = "http://127.0.0.1:3001"
USERNAME = os.environ["KUMA_ADMIN_USER"]
PASSWORD = os.environ["KUMA_ADMIN_PASS"]

api = UptimeKumaApi(KUMA_URL)

if api.need_setup():
    api.setup(USERNAME, PASSWORD)
api.login(USERNAME, PASSWORD)

# Direkte nåbare fra CT 204 (vmbr0) -- ping der HTTP ikke er poenget, for å unngå
# å måtte legge til nye iptables-unntak per node.
direct_nodes = [
    {"slug": "proxmox-host", "title": "Proxmox Host", "type": MonitorType.PING, "hostname": "192.168.1.50"},
    {"slug": "mgmt-node", "title": "mgmt-node", "type": MonitorType.PING, "hostname": "192.168.1.200"},
    {"slug": "web-01", "title": "web-01", "type": MonitorType.HTTP, "url": "http://192.168.1.203"},
    {"slug": "kali-01", "title": "Kali", "type": MonitorType.PING, "hostname": "192.168.1.202"},
]

existing = {m["name"]: m for m in api.get_monitors()}

# OPNsense sin WAN-side (192.168.1.136) svarer verken på ping, 443 eller 22 fra
# vmbr0 -- oppdaget under faktisk kjøring, IKKE dokumentert tidligere (bedre
# innelåst enn antatt). Reelt operasjonelt relevant sjekk er derfor LAN-siden
# (10.0.0.1), som kun Kali kan nå -- samme push-monitor-mønster som Metasploitable.
if "OPNsense" in existing and existing["OPNsense"]["type"] != "push":
    api.delete_monitor(existing["OPNsense"]["id"])
    existing = {m["name"]: m for m in api.get_monitors()}

monitor_ids = {}

for n in direct_nodes:
    if n["title"] in existing:
        mid = existing[n["title"]]["id"]
    else:
        kwargs = {
            "type": n["type"],
            "name": n["title"],
            "interval": 60,
            "retryInterval": 60,
            "maxretries": 2,
        }
        if n["type"] == MonitorType.PING:
            kwargs["hostname"] = n["hostname"]
        elif n["type"] == MonitorType.HTTP:
            kwargs["url"] = n["url"]
        r = api.add_monitor(**kwargs)
        mid = r["monitorID"]
    monitor_ids[n["slug"]] = mid

# Metasploitable (10.0.0.176) har ingen rute fra vmbr0 -- CT 204 kan strukturelt
# ikke nå den direkte (med hensikt, se homelab.md). Samme gjelder nå OPNsense sin
# LAN-side. Begge bruker PUSH-monitorer: Kali (dual-homed) sjekker over sitt
# eth1/vmbr1-interface og sender heartbeat til Kuma over vmbr0. Ingen ny rute
# eller brannmuråpning inn i vmbr1 i noen retning.
push_nodes = [
    ("metasploitable", "Metasploitable"),
    ("opnsense", "OPNsense"),
]
push_tokens = {}
for slug, title in push_nodes:
    if title in existing:
        mid = existing[title]["id"]
    else:
        r = api.add_monitor(
            type=MonitorType.PUSH,
            name=title,
            interval=120,
            retryInterval=120,
            maxretries=2,
        )
        mid = r["monitorID"]
    monitor_ids[slug] = mid
    push_tokens[slug] = api.get_monitor(mid)["pushToken"]

# Homepage sin uptimekuma-widget leser kun status-side-nivå (aggregert), ikke
# enkeltmonitorer -- derfor én status-side per monitor, ikke én delt side.
status_pages = [
    ("proxmox-host", "Proxmox Host"),
    ("mgmt-node", "mgmt-node"),
    ("web-01", "web-01"),
    ("kali-01", "Kali"),
    ("metasploitable", "Metasploitable"),
    ("opnsense", "OPNsense"),
]

existing_pages = {p["slug"] for p in api.get_status_pages()}
for slug, title in status_pages:
    if slug not in existing_pages:
        api.add_status_page(slug, title)
    mid = monitor_ids[slug]
    api.save_status_page(
        slug,
        title=title,
        publicGroupList=[{"name": "Status", "weight": 1, "monitorList": [{"id": mid}]}],
    )

# Push-tokenene er ikke administrasjonspassord (kan kun poste heartbeats til ÉN
# monitor hver), men holdes likevel unna stdout/chat -- skrives til filer kun
# lesbare av root i containeren, og relayes videre til Kali sitt heartbeat-skript
# gjennom samme scp/pct-push-mønster som andre filer i dette repoet.
for slug, token in push_tokens.items():
    path = f"/root/.{slug}_push_token"
    with open(path, "w") as f:
        f.write(token)
    os.chmod(path, 0o600)

print(json.dumps({"monitor_ids": monitor_ids, "status_pages": [s[0] for s in status_pages]}, indent=2))
