# Homelab 2.4

**Versjon:** 2.4 — 16. juli 2026 | **Status:** Fullt operasjonell | **Forrige versjon:** 2.3 — 1. juli 2026

---

Bygget på Proxmox VE (192.168.1.50) for offensiv sikkerhetstesting og data engineering. Målet er et kontrollert miljø der angrepsscenarier kan kjøres uten risiko for produksjonsnettet.

Labben består av to nettverkssegmenter:

- **vmbr0 (192.168.1.x)** — hjemmenett/admin-siden
- **vmbr1 (10.0.0.x)** — isolert lab-nett, der angrep og mål lever

OPNsense fungerer som gateway og DHCP-server mellom segmentene. Kali er dual-homed og kan nå begge. Metasploitable er fullstendig isolert på 10.0.0.x.

**Ekstern tilgang:** Tailscale er installert på Proxmox-hosten og fungerer som subnet router. All ekstern tilgang til labben (inkludert Proxmox web UI på port 8006) går gjennom Tailscale. Ingen porter er eksponert mot internett.

---

## 1. Changelog

### Changelog (v1.0 → v2.0)

| Endring | Detalj |
|---|---|
| Tailscale dokumentert | Installert på Proxmox-host, subnet router aktivert |
| Proxmox web UI tilgang klargjort | Kun tilgjengelig via Tailscale |
| iptables persistens — status ukjent | Må verifiseres (se åpne punkter) |
| web-01 IP-endring notert | Endret fra 192.168.1.201 → 192.168.1.203 |
| Ansible-filer bekreftet | Fortsatt på mgmt-node |

### Changelog (v2.0 → v2.1)

| Endring | Detalj |
|---|---|
| Proxmox host vmbr1 IP korrigert | 10.0.0.254 var aldri statisk konfigurert — det var en manuell `ip addr add` som ikke overlevde reboot. vmbr1 har bevisst ingen host-IP. |
| Metasploitable IP bekreftet | 10.0.0.176 — verifisert via nmap-scan fra Kali |
| OPNsense SSH bekreftet fungerende | Alias oppsatt og verifisert |
| DHCP lease-sjekk oppdatert | OPNsense 26.1 bruker Kea — bruk nmap-scan i stedet |

### Changelog (v2.1 → v2.2)

| Endring | Detalj |
|---|---|
| iptables-regel for port 8006 | DROP for alle, ACCEPT kun for tailscale0 — verifisert og lagret |
| iptables persistens bekreftet | Lagret til /etc/iptables/rules.v4 via iptables-persistent |
| Proxmox Tailscale-IP dokumentert | 100.108.236.64 — dette er riktig URL for web UI |
| Proxmox web UI URL oppdatert | https://100.108.236.64:8006 (ikke 192.168.1.50:8006) |

### Changelog (v2.2 → v2.3)

| Endring | Detalj |
|---|---|
| SSH hardening bekreftet | PasswordAuthentication no på alle noder — proxmox, mgmt, web01, kali |
| Baseline snapshots tatt | VM 101 og 300 snapshottet i Proxmox |
| LXC backups tatt via vzdump | CT 200, 201, 202 — lagret i /var/lib/vz/dump/ |

### Changelog (v2.3 → v2.4)

| Endring | Detalj |
|---|---|
| Port 3128 (spiceproxy) låst til tailscale0 | Samme iptables-mønster som port 8006 — ACCEPT kun på tailscale0, DROP for alt annet. Persistert til /etc/iptables/rules.v4. |
| vmbr1 host-IP bekreftet fraværende (bevisst) | 10.0.0.254 var aldri statisk — manuell `ip addr add` som ikke overlevde reboot. vmbr1 har nå ingen host-IP; strukturell isolasjon er sterkere enn brannmurregler. |
| Ansible-playbooks pushet til Git | Kryptert med Ansible Vault (AES256), tilgjengelig på GitHub: Idiri/WDhomelab. |
| OPNsense firewall-regler dokumentert | pfctl-audit kjørt — se seksjon "OPNsense Firewall Audit — 16. juli 2026". |

---

## 2. Arkitektur & Infrastruktur (As-Built)

### Nettverksoversikt

| Segment | Bridge | Subnett | Rolle |
|---|---|---|---|
| WAN / Admin | vmbr0 | 192.168.1.0/24 | Hjemmenett, SSH-tilgang fra Mac |
| LAN / Lab | vmbr1 | 10.0.0.0/24 | Isolert angrepsnettverk |
| VPN | Tailscale | 100.x.x.x | Ekstern tilgang, subnet router på host |

### Noder

| ID | Navn | Type | vmbr0 IP | vmbr1 IP | Rolle | Status |
|---|---|---|---|---|---|---|
| — | Proxmox host | Hypervisor | 192.168.1.50 | Ingen (bevisst) | Hypervisor, Tailscale subnet router (100.108.236.64) | ✅ Running |
| 101 | opnsense-gateway | VM (FreeBSD) | WAN: DHCP 192.168.1.136 | 10.0.0.1/24 | Firewall, DHCP-server for vmbr1 | ✅ Running |
| 200 | mgmt-node | LXC | 192.168.1.200 | — | Ansible-kontrollnode | ✅ Running |
| 201 | web-01 | LXC | 192.168.1.203 | — | Nginx 1.22.1 webserver (mål) | ✅ Running |
| 202 | kali-01 | LXC | 192.168.1.202 | 10.0.0.10/24 | Kali Linux, angrepsnode | ✅ Running |
| 300 | metasploitable | VM (Linux) | — | 10.0.0.176/24 (DHCP) | Sårbart mål | ✅ Running |
| 9001 | kali-template | VM | — | vmbr1 | Ren Kali-template | ⏹ Stopped |

Merk: web-01 fikk ny IP 192.168.1.203 (tidligere .201). Alle configs og SSH-aliaser er oppdatert.

### Tailscale-oppsett

Tailscale er installert direkte på Proxmox-hosten:

```bash
# Verifiser Tailscale-status
tailscale status

# Hent Tailscale-IP
tailscale ip

# Subnet router-annonsering (192.168.1.0/24)
tailscale up --advertise-routes=192.168.1.0/24 --accept-routes
```

Proxmox Tailscale-IP: 100.108.236.64  
Proxmox web UI: https://100.108.236.64:8006 (ikke 192.168.1.50:8006)

Port 8006 er låst med iptables — kun tilgjengelig via tailscale0:

```bash
# Disse reglene er aktive og lagret i /etc/iptables/rules.v4
iptables -I INPUT -i tailscale0 -p tcp --dport 8006 -j ACCEPT
iptables -I INPUT -p tcp --dport 8006 -j DROP
```

- 192.168.1.50:8006 → ❌ timed out (blokkert for hele LAN-et)
- 100.108.236.64:8006 → ✅ fungerer (kun via Tailscale)
- Ingen åpne porter mot internett

### Dual-homed Kali-oppsett

```
eth0 → vmbr0 → 192.168.1.202/24   # Admin-tilgang fra Mac
eth1 → vmbr1 → 10.0.0.10/24       # Direkte tilgang til lab-nettet
```

Kali er den eneste noden som kan nå begge segmenter. Den fungerer også som SSH jump-host for å nå OPNsense. Metasploitable er kun synlig fra kali via 10.0.0.x.

### Ansible-filer (mgmt-node / 192.168.1.200)

| Fil | Rolle |
|---|---|
| deploy_ct.yml | Spinner opp nye LXC-containere |
| setup_web.yml | Konfigurerer Nginx på web-01 |
| hosts.ini | Inventory-fil |
| proxmox_vars.yml | Variabler for Proxmox-API (Ansible Vault-kryptert) |

Primær orkestrerings-metode ("host-exec"):

```bash
ssh root@192.168.1.50 pct exec <vmid> -- <cmd>
```

### SSH-konfigurasjon (~/.ssh/config på Mac)

```
Host proxmox
    HostName 192.168.1.50
    User root
    IdentityFile ~/.ssh/homelab_key

Host mgmt
    HostName 192.168.1.200
    User root
    IdentityFile ~/.ssh/homelab_key

Host web01
    HostName 192.168.1.203
    User root
    IdentityFile ~/.ssh/homelab_key

Host kali
    HostName 192.168.1.202
    User root
    IdentityFile ~/.ssh/homelab_key

Host opnsense
    HostName 10.0.0.1
    User root
    IdentityFile ~/.ssh/homelab_key
    ProxyJump kali
```

---

## 3. Kronologisk Utviklingslogg

| Fase | Hva ble gjort | Resultat |
|---|---|---|
| Fase 1 — Grunnlag | Proxmox installert, vmbr0/vmbr1 konfigurert, CT 200/201/202 opprettet | Basis-infrastruktur oppe |
| Fase 2 — Nettverkskonflikt | Containere havnet på 10.0.0.x. Løst ved å flytte til vmbr0, aktivere ip_forward=1 og iptables MASQUERADE på host | Internett-tilgang til containere |
| Fase 3 — Ansible-orkestrering | deploy_ct.yml og setup_web.yml skrevet på mgmt-node. "Host-exec"-metoden etablert | Automatisert CT-deploy |
| Fase 4 — Angrepsverifisering | Kali → Nmap → Web-01 verifisert. Full angrepsloop bekreftet | Lab klar for offensiv testing |
| Fase 5 — Lab-isolasjon | Metasploitable (VM 300) flyttet til vmbr1. Kali dual-homed med eth1 på 10.0.0.10 | Mål isolert fra hjemmenett |
| Fase 6 — OPNsense-installasjon | VM 101 opprettet. Løst ved å øke RAM til 4GB, kjøre opnsense-installer fra live-shell, fjerne ISO-enheten fra VM | OPNsense installert på disk |
| Fase 7 — OPNsense-konfigurasjon | WAN=vtnet0, LAN=vtnet1, LAN IP 10.0.0.1/24, DHCP 10.0.0.100–200. SSH aktivert via webgui | Gateway og DHCP operasjonelt |
| Fase 8 — Endepunkt-verifisering | Metasploitable fikk DHCP-lease 10.0.0.176. Kali pinger metasploitable med 0% pakketap | Lab fullt operasjonell |
| Fase 9 — Tailscale | Tailscale installert på Proxmox-host. Subnet router aktivert for 192.168.1.0/24. Proxmox web UI låst til Tailscale | Sikker ekstern tilgang uten eksponerte porter |
| Fase 10 — SSH hardening | PasswordAuthentication no satt eksplisitt på alle noder via sed + sshd restart | Kun nøkkelbasert SSH på alle noder |
| Fase 11 — Baseline snapshot | VM 101 og 300 snapshottet i Proxmox. CT 200/201/202 backed opp via vzdump | Kjent god tilstand lagret |

### Kritiske lærdommer

- Aldri rediger OPNsense config.xml direkte — krevde full reinstallasjon
- OPNsense 26.1 detekterer live media basert på om ISO-enheten er koblet til — fjern med `qm set 101 --ide2 none`
- `opnsense-installer` kan kjøres fra live-shellet (option 8) — ikke prøv å fange boot-menyen

---

## 4. "Golden Path" for drift

### Helsesjekk (kjør dette hver gang du logger inn)

```bash
# 1. Verifiser at alle noder kjører
ssh proxmox 'qm list; echo "---"; pct list'

# 2. Verifiser at OPNsense LAN er oppe
ssh kali "ping -c 2 10.0.0.1"

# 3. Verifiser at metasploitable er oppe (OPNsense 26.1 bruker Kea — ingen lease-fil, bruk nmap)
ssh kali "nmap -sn 10.0.0.0/24"

# 4. Verifiser at kali kan nå metasploitable
ssh kali "ping -c 2 10.0.0.176"

# 5. Verifiser web-01
curl -I http://192.168.1.203

# 6. Verifiser Tailscale
tailscale status
```

### Baseline snapshots & backups (1. juli 2026)

| Node | Type | Navn/Fil | Størrelse |
|---|---|---|---|
| VM 101 — OPNsense | Proxmox snapshot | baseline-1jul2026 | — |
| VM 300 — Metasploitable | Proxmox snapshot | baseline-1jul2026 | — |
| CT 200 — mgmt-node | vzdump | vzdump-lxc-200-2026_07_01-18_21_27.tar.zst | 825MB |
| CT 201 — web-01 | vzdump | vzdump-lxc-201-2026_07_01-18_21_41.tar.zst | 194MB |
| CT 202 — kali-01 | vzdump | vzdump-lxc-202-2026_07_01-18_21_46.tar.zst | 3.02GB |

Alle backups lagret på Proxmox-host: `/var/lib/vz/dump/`

```bash
# Reverter VM til snapshot:
ssh proxmox 'qm rollback 101 baseline-1jul2026'
ssh proxmox 'qm rollback 300 baseline-1jul2026'

# Gjenopprett LXC fra backup:
ssh proxmox 'pct restore 200 /var/lib/vz/dump/vzdump-lxc-200-2026_07_01-18_21_27.tar.zst'

# Ta ny snapshot før hver offensive økt:
ssh proxmox 'qm snapshot 300 pre-session-$(date +%Y%m%d) --description "Pre-session snapshot"'
```

### OPNsense WebGUI (tunnell via Kali)

```bash
ssh -f -N -L 8443:10.0.0.1:443 kali
# Åpne https://localhost:8443 i nettleseren
```

### Start Metasploitable

```bash
ssh proxmox 'qm start 300'
# Vent ~30s, sjekk at den er oppe:
ssh kali "nmap -sn 10.0.0.0/24"
```

### Offensive tester

```bash
# Fra kali → scan metasploitable
ssh kali "nmap -sV 10.0.0.176"

# Fra kali → scan web-01
ssh kali "nmap 192.168.1.203"
```

---

## 5. Åpne punkter & neste steg

| Prioritet | Punkt | Status |
|---|---|---|
| ✅ Ferdig | iptables port 8006 låst til tailscale0 og lagret til /etc/iptables/rules.v4 | Gjort 1. juli |
| ✅ Ferdig | SSH hardening — PasswordAuthentication no på alle noder | Gjort 1. juli |
| ✅ Ferdig | Baseline snapshot tatt — VM 101, 300 + vzdump CT 200, 201, 202 | Gjort 1. juli |
| ✅ Ferdig | Dokumenter OPNsense firewall-regler (inter-segment policy vmbr0↔vmbr1) | [Se audit-seksjon](#opnsense-firewall-audit--16-juli-2026) — ⚠️ ingen inter-segment filtrering konfigurert |
| ✅ Ferdig | Push Ansible-playbooks til Git for backup | Gjort 16. juli — Ansible Vault-kryptert, GitHub: Idiri/WDhomelab |
| ✅ Ferdig | Legg til OPNsense-regel: blokker 10.0.0.x → 192.168.1.x | Gjort 16. juli — verifisert fra Metasploitable: ping 192.168.1.203 → 100% pakketap, curl → couldn't connect to host (tidsavbrutt, ingen respons — konsistent med silent drop). OPNsense LAN (10.0.0.1) og L2-noder (10.0.0.x) upåvirket. |
| 🔴 Høy | Begrens OPNsense admin-tilgang (port 80/443/22 på LAN) til kun Kali (10.0.0.10) | Ikke gjort |
| 🔴 Høy | Bytt fra root SSH til dedikerte brukere på alle noder | Ikke gjort |
| 🟠 Medium | Offensiv testing av Nginx 1.22.1 på web-01 | Ikke startet |
| 🟡 Lav | Legg til SIEM (Wazuh eller Security Onion) for nettverkssynlighet | Ikke startet |
| 🟡 Lav | Sett opp reverse proxy foran web-01 | Ikke startet |
| 🟡 Lav | Snapshot Metasploitable før hver offensive økt (se Golden Path) | Rutine etablert |

---

## 6. Sikkerhetsstatus

| Område | Status | Notat |
|---|---|---|
| Internett-eksponering | ✅ Ingen | Ingen åpne porter mot internett |
| Nettverkssegmentering | ✅ OK | vmbr0 / vmbr1 med OPNsense mellom |
| Ekstern tilgang | ✅ Tailscale | Subnet router på Proxmox-host |
| Proxmox web UI | ✅ Låst | iptables blokkerer 8006 på LAN — kun 100.108.236.64:8006 via Tailscale |
| SSH-autentisering | ✅ Bekreftet | PasswordAuthentication no på alle noder — verifisert 1. juli |
| SSH-bruker | ⚠️ Root | Bør byttes til dedikerte brukere |
| Firewall-regler | ✅ Sikret | Inter-segment blokkering aktiv: 10.0.0.x → 192.168.1.x blokkert i OPNsense — verifisert 16. juli. OPNsense admin-porter (80/443/22) på LAN fortsatt åpne for alle 10.0.0.x — begrensning til kun Kali (10.0.0.10) gjenstår. |
| iptables persistens | ✅ Bekreftet | Lagret til /etc/iptables/rules.v4 — overlever reboot |
| Proxmox REST API på vmbr1 | ✅ Sikret | vmbr1 har ingen host-IP — ingen rute fra 10.0.0.x til hypervisoren. Port 8006 og 3128 låst til tailscale0 via iptables. |
| Logging/SIEM | ❌ Mangler | Ingen synlighet på nettverksnivå |

---

## OPNsense Firewall Audit — 16. juli 2026

**Grensesnitt bekreftet:** vtnet0 = WAN (192.168.1.136/24, DHCP fra hjemmeruter), vtnet1 = LAN (10.0.0.1/24)  
pf opptid på audittidspunkt: 2 timer 09 minutter.

### Fra vmbr0 (192.168.1.x / WAN) inn til vmbr1 (10.0.0.x / LAN)

| Regel | Kilde | Mål | Aksjon |
|---|---|---|---|
| Anti-spoof (innkommende på feil grensesnitt) | 192.168.1.0/24 inn på vtnet1 | any | ❌ BLOCK DROP |
| Standard default deny | any | any | ❌ BLOCK DROP |
| Ingen pass-regel | 192.168.1.x | 10.0.0.x | — |

**Konklusjon:** Hjemmenett kan ikke initiere tilkoblinger til lab-nettet. Ingen inngående port-videresending (no rdr) fra WAN.

### Fra vmbr1 (10.0.0.x / LAN) ut til vmbr0 (192.168.1.x) eller WAN

| Regel | Kilde | Mål | Aksjon |
|---|---|---|---|
| Standard LAN-regel | 10.0.0.0/24 | **any** (inkl. 192.168.1.x og internett) | ✅ PASS (stateful) |
| Ruting ut via WAN | vtnet0-IP | utenfor vtnet0-nett | ✅ PASS |

**⚠️ Kritisk funn:** Standard LAN-regel (`pass in quick on vtnet1 inet from (vtnet1:network) to any`) tillater ALL trafikk fra 10.0.0.x til alle destinasjoner — inkludert hjemmenett (192.168.1.x). En kompromittert Metasploitable kan nå hjemmenett direkte gjennom OPNsense. Ingen inter-segment filtrering er konfigurert.

### Tilgang til OPNsense selv fra LAN (vtnet1)

| Port | Protokoll | Fra | Aksjon |
|---|---|---|---|
| 22 (SSH) | TCP | 10.0.0.x (alle) | ✅ PASS |
| 80 (HTTP) | TCP | 10.0.0.x (alle) | ✅ PASS |
| 443 (HTTPS) | TCP | 10.0.0.x (alle) | ✅ PASS |

### NAT

| Regel | Kilde | Mål | Oversetting |
|---|---|---|---|
| Masquerade (standard) | 10.0.0.0/24 | any | → 192.168.1.136 (WAN-IP), porter 1024–65535 |
| ISAKMP static-port | 10.0.0.0/24 port 500 | any | → 192.168.1.136, static port |

Ingen inngående port-videresending fra WAN til LAN.

### Åpne sikkerhetspunkter identifisert under audit

1. **Ingen inter-segment filtrering** — Bør legges til OPNsense LAN-regler som blokkerer 10.0.0.x → 192.168.1.x for alle noder unntatt Kali (10.0.0.10). Metasploitable og andre mål skal ikke kunne nå hjemmenett.
2. **OPNsense web UI tilgjengelig fra hele LAN** — Vurder å begrense port 80/443/22 på vtnet1 til kun Kali-IP (10.0.0.10).
