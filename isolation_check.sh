#!/bin/sh
set -u
# Kjøres via systemd-timer på mgmt-node hvert minutt. Eksersiserer OPNsense sin
# inter-segment-blokkeringsregel (10.0.0.x -> 192.168.1.x) reelt, ved å be Kali
# (10.0.0.10) hente http://192.168.1.203 (web-01) over sitt eget eth1/vmbr1
# -interface. Bruker "host-exec"-mønsteret (ssh proxmox -> pct exec 202), siden
# mgmt-node ikke har direkte SSH-tilgang til Kalis IP (kun til proxmox-hosten).
#
# Semantikk (viktig, motsatt av vanlig "opp/nede"-overvåking):
#   - http_code == 000 (curl klarte ikke koble til) -> isolasjonen VIRKER,
#     status = "isolert" (dette er den friske/forventede tilstanden)
#   - et ekte HTTP-svar (200, 403, osv.) -> isolasjonen er BRUTT,
#     status = "LEKKASJE" (dette skal aldri skje og betyr en reell sikkerhetsfeil)

HTTP_CODE=$(ssh -o ConnectTimeout=8 root@192.168.1.50 \
    "pct exec 202 -- curl -s -o /dev/null -m 5 --interface eth1 -w '%{http_code}' http://192.168.1.203" \
    2>/dev/null)
HTTP_CODE=${HTTP_CODE:-000}
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ "$HTTP_CODE" = "000" ]; then
    STATUS="isolert"
else
    STATUS="LEKKASJE"
fi

cat > /root/isolation.json <<EOF
{"status": "$STATUS", "http_code": "$HTTP_CODE", "last_checked": "$TIMESTAMP"}
EOF

scp /root/isolation.json root@192.168.1.50:/root/isolation.json >/dev/null 2>&1
ssh root@192.168.1.50 "pct push 203 /root/isolation.json /opt/homepage/status/isolation.json && rm -f /root/isolation.json" >/dev/null 2>&1
rm -f /root/isolation.json
