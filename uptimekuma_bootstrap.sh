#!/bin/sh
set -eu

apt update
apt install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

mkdir -p /opt/uptime-kuma/data

cd /opt/uptime-kuma
docker compose up -d

DEBIAN_FRONTEND=noninteractive apt install -y iptables iptables-persistent

# Samme mønster som CT 203/port 3000 (se homepage_bootstrap.sh) — DOCKER-USER er
# det eneste laget som faktisk teller, fordi Docker DNAT-omskriver destinasjonen
# før INPUT/FORWARD nås. To navngitte kilder i stedet for én:
#   192.168.1.204 — Homepage-containeren, for status-page-widgeten (per-node
#                    uptimekuma-widgets i services.yaml leser Kuma sine
#                    status-page-endepunkter direkte)
#   192.168.1.50  — hva Tailscale-forwardet trafikk fremstår som etter SNAT når
#                    et menneske åpner Kuma sitt eget UI direkte via Tailscale
#                    (samme mønster som homepage sin egen tilgang)
#   192.168.1.202 — Kali, som poster push-heartbeats for Metasploitable-monitoren
#                    (Metasploitable/10.0.0.176 har ingen rute fra CT 204/vmbr0,
#                    så Kali sjekker over sitt eget eth1 og relayer resultatet)
# Loopback må eksplisitt tillates FØR den generelle DROP-regelen -- uten denne
# blokkerer INPUT-DROP-regelen også 127.0.0.1-trafikk, som brøt lokale
# oppsettsskript kjørt inne i containeren (funnet under faktisk kjøring).
iptables -I INPUT -i lo -j ACCEPT
iptables -I INPUT -s 192.168.1.204 -p tcp --dport 3001 -j ACCEPT
iptables -I INPUT -s 192.168.1.50 -p tcp --dport 3001 -j ACCEPT
iptables -I INPUT -s 192.168.1.202 -p tcp --dport 3001 -j ACCEPT
iptables -I INPUT 5 -p tcp --dport 3001 -j DROP
iptables -I DOCKER-USER 1 -i eth0 -s 192.168.1.204 -p tcp --dport 3001 -j RETURN
iptables -I DOCKER-USER 2 -i eth0 -s 192.168.1.50 -p tcp --dport 3001 -j RETURN
iptables -I DOCKER-USER 3 -i eth0 -s 192.168.1.202 -p tcp --dport 3001 -j RETURN
iptables -I DOCKER-USER 4 -i eth0 -p tcp --dport 3001 -j DROP
iptables-save > /etc/iptables/rules.v4

# Bevisst IKKE lagt til: en tilsvarende FORWARD-regel på Proxmox-hosten for port
# 3001. v2.6-funnet for port 3000 gjelder identisk her — Tailscale sin egen
# ts-forward-kjede ACCEPTerer terminalt ALL trafikk fra tailscale0 til hele det
# annonserte subnettet (192.168.1.0/24) FØR pakken noensinne når skreddersydde
# FORWARD-regler lenger ned. En slik regel ville vært like misvisende dead code
# som den for port 3000 — DOCKER-USER over er og forblir det eneste reelle laget.
