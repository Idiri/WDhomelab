#!/bin/sh
set -u
# Bevisst uten -e: hvis ett mål mangler token-fil eller curl feiler, skal
# skriptet likevel forsøke det andre målet, ikke avbryte tidlig.
# Kjøres via systemd-timer på Kali hvert minutt. Sjekker to mål over Kalis eget
# eth1/vmbr1-interface (den eneste noden med en reell rute til vmbr1) og relayer
# resultatet som push-heartbeats til Uptime Kuma over vmbr0:
#   - Metasploitable (10.0.0.176) -- ingen rute fra CT 204/vmbr0 i det hele tatt
#   - OPNsense LAN-side (10.0.0.1) -- WAN-siden (192.168.1.136) svarer verken på
#     ping, 443 eller 22 fra vmbr0 (oppdaget under faktisk kjøring), så den
#     operasjonelt relevante sjekken er uansett kun mulig fra LAN-siden
# Kontrollretningen er alltid "Kali initierer utover", aldri "noe utenfra
# initierer inn" -- ingen ny rute eller brannmuråpning inn i vmbr1.
#
# OPNsense sjekkes over TCP (https/443), ikke ping (funnet 25. juli): en
# restrestriksjon fra det uferdige Fase 17-forsøket (pfctl -sr, regel
# "block drop in quick inet from (vtnet1:network) to (self)") blokkerer all
# ikke-TCP/ikke-DHCP trafikk fra lab-nettet til OPNsense sin egen LAN-IP.
# SSH/HTTP/HTTPS til (self) har egne eksplisitte quick pass-regler foran
# blokkeringen og er derfor upåvirket -- bekreftet med curl/nc mot 10.0.0.1:443
# fra Kalis eth1. Ping-basert sjekk ga dermed falsk "down" for en node som
# faktisk er oppe. Metasploitable har ingen slik regel og sjekkes fortsatt med
# ping.

KUMA_URL="http://192.168.1.205:3001"

push_heartbeat() {
    target_ip="$1"
    token_file="$2"
    label="$3"
    method="$4"

    if [ ! -f "$token_file" ]; then
        echo "Push-token mangler: $token_file" >&2
        return 1
    fi
    token=$(cat "$token_file")

    case "$method" in
        tcp443)
            if curl -sk -m 5 --interface eth1 -o /dev/null "https://$target_ip"; then
                status=up
                msg="$label svarer på https/443 over eth1"
            else
                status=down
                msg="$label svarer ikke på https/443 over eth1"
            fi
            ;;
        *)
            if ping -c 2 -W 2 -I eth1 "$target_ip" > /dev/null 2>&1; then
                status=up
                msg="$label svarer på ping over eth1"
            else
                status=down
                msg="$label svarer ikke på ping over eth1"
            fi
            ;;
    esac

    curl -s -m 5 -G "$KUMA_URL/api/push/$token" \
        --data-urlencode "status=$status" \
        --data-urlencode "msg=$msg" \
        --data-urlencode "ping=" \
        > /dev/null
}

push_heartbeat 10.0.0.176 /root/.metasploitable_push_token "Metasploitable" ping
push_heartbeat 10.0.0.1 /root/.opnsense_push_token "OPNsense LAN" tcp443
