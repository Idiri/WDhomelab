#!/bin/sh
set -eu

apt update
apt install -y ca-certificates curl gnupg git

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# wazuh-indexer (OpenSearch) refuses to start below vm.max_map_count=262144.
# This is a host-wide kernel parameter, not namespaced -- an unprivileged LXC
# container cannot set it (permission denied), so it must be set on the
# Proxmox HOST itself (see /etc/sysctl.d/99-wazuh-indexer.conf there, and
# docs/homelab.md Fase 28 for the failed-attempt diagnosis). Since the kernel
# is shared, the container sees the host's value automatically -- nothing to
# do here.

git clone --branch v4.14.7 --depth 1 https://github.com/wazuh/wazuh-docker.git /opt/wazuh-docker
cd /opt/wazuh-docker/single-node

# Fase 28: deliberately resource-constrained, NOT the official 8GB-dedicated
# spec -- host had ~9GB free total, shared with 5 other live services. Explicit
# mem_limit on every container, indexer JVM heap cut from its multi-GB default
# to 1GB, so if memory pressure forces an OOM-kill, it takes Wazuh's own
# container down, not homepage/uptime-kuma. See docs/homelab.md for the real
# headroom numbers this was sized against.
cat > docker-compose.override.yml <<'OVERRIDE'
services:
  wazuh.indexer:
    mem_limit: 2g
    mem_reservation: 1g
    environment:
      - OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
  wazuh.manager:
    mem_limit: 1g
    mem_reservation: 512m
  wazuh.dashboard:
    mem_limit: 1g
    mem_reservation: 512m
OVERRIDE

# Official prerequisite: indexer TLS certs must exist before first "up".
docker compose -f generate-indexer-certs.yml run --rm generator

docker compose up -d

DEBIAN_FRONTEND=noninteractive apt install -y iptables iptables-persistent

# Same DOCKER-USER pattern as CT 203/204 (see homepage_bootstrap.sh) -- Docker's
# DNAT rewrite in PREROUTING happens before INPUT/FORWARD ever see the packet,
# so DOCKER-USER is the only real enforcement layer, INPUT is a harmless second
# layer for any future non-Docker traffic on these ports.
#
# Dashboard (443): same named-source pattern as Homepage/Kuma -- only
# 192.168.1.50 (what Tailscale-forwarded traffic looks like after SNAT).
iptables -I INPUT -s 192.168.1.50 -p tcp --dport 443 -j ACCEPT
iptables -I INPUT 2 -p tcp --dport 443 -j DROP
iptables -I DOCKER-USER 1 -i eth0 -s 192.168.1.50 -p tcp --dport 443 -j RETURN
iptables -I DOCKER-USER 2 -i eth0 -p tcp --dport 443 -j DROP

# Agent ports (1514 events, 1515 enrollment): Fase 28 scope is Proxmox as the
# only agent, so the only permitted source is Proxmox's own address. Expand
# per-host as more agents are added later -- not opened broadly up front.
iptables -I INPUT -s 192.168.1.50 -p tcp --dport 1514 -j ACCEPT
iptables -I INPUT -s 192.168.1.50 -p tcp --dport 1515 -j ACCEPT
iptables -I INPUT 5 -p tcp --dport 1514 -j DROP
iptables -I INPUT 6 -p tcp --dport 1515 -j DROP
iptables -I DOCKER-USER 3 -i eth0 -s 192.168.1.50 -p tcp --dport 1514 -j RETURN
iptables -I DOCKER-USER 4 -i eth0 -s 192.168.1.50 -p tcp --dport 1515 -j RETURN
iptables -I DOCKER-USER 5 -i eth0 -p tcp --dport 1514 -j DROP
iptables -I DOCKER-USER 6 -i eth0 -p tcp --dport 1515 -j DROP

iptables-save > /etc/iptables/rules.v4
