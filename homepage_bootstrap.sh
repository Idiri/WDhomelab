#!/bin/sh
set -eu

apt update
apt install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

mkdir -p /opt/homepage/config

cd /opt/homepage
docker compose up -d

DEBIAN_FRONTEND=noninteractive apt install -y iptables iptables-persistent

# Rekkefolge er kritisk: ACCEPT settes inn ved posisjon 1, DROP eksplisitt ved
# posisjon 2 rett bak. To separate "-I INPUT" (uten posisjon) ville satt DROP
# ovest og blokkert alt, inkludert den tiltenkte kilden.
#
# INPUT-regelen alene stopper IKKE trafikk til en docker-publisert port: Docker
# DNAT-omskriver "-d 192.168.1.204" til container-broens interne IP (f.eks.
# 172.18.0.2) i PREROUTING, FØR pakken når INPUT eller FORWARD. INPUT-regelen
# under er derfor kun et harmløst andre lag for ev. fremtidig ikke-Docker-trafikk
# på denne porten — den reelle sperren må stå i DOCKER-USER (kjeden Docker
# garanterer kjøres FØR sine egne genererte FORWARD-regler, og som IKKE skrives
# over ved "docker compose restart"), matchet på kilde+interface (ikke -d, siden
# destinasjonen allerede er omskrevet på dette tidspunktet i kjeden).
iptables -I INPUT -s 192.168.1.50 -p tcp --dport 3000 -j ACCEPT
iptables -I INPUT 2 -p tcp --dport 3000 -j DROP
iptables -I DOCKER-USER 1 -i eth0 -s 192.168.1.50 -p tcp --dport 3000 -j RETURN
# Fase 27: rate-limited LOG rett foran DROP, for grunnleggende synlighet av
# avviste forsøk. Krever net.netfilter.nf_log_all_netns=1 på Proxmox-hosten
# (satt i /etc/sysctl.d/99-nf-log-netns.conf) — uten den blir LOG-mål inne i en
# LXC-container sin netns stille forkastet av kjernen, uansett hva denne regelen
# sier (bekreftet empirisk under Fase 27, se docs/homelab.md).
iptables -I DOCKER-USER 2 -i eth0 -p tcp --dport 3000 -m limit --limit 10/min --limit-burst 20 -j LOG --log-prefix "CT203-3000-DROP: " --log-level 4
iptables -I DOCKER-USER 3 -i eth0 -p tcp --dport 3000 -j DROP
iptables-save > /etc/iptables/rules.v4
