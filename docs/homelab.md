# Homelab 2.4

**Versjon:** 2.4 — 16. juli 2026 | **Status:** Fullt operasjonell | **Forrige versjon:** 2.3 — 1. juli 2026

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
| Proxmox host vmbr1 IP dokumentert | 10.0.0.254 — statisk, Proxmox REST API eksponert på lab-nettet |
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
| Fysisk flytting og rengjøring av Proxmox-host | ThinkCentre M70q flyttet bort fra ruteren (kilde til støvopphopning) og rengjort. Tailscale falt fra under nedetiden — gjenopprettet etter oppstart |
| Full Golden Path-helsesjekk etter flytting | Alle noder (101, 200, 201, 202, 300) verifisert oppe og fungerende — ingen konfigurasjonsdrift funnet |
| Ny baseline snapshot-runde | VM 101 + 300 snapshottet (baseline-16jul2026), CT 200/201/202 vzdump-backet opp på nytt |
| Proxmox API-token lekket og rotert | Plaintext-token oppdaget i proxmox_vars.yml under git-oppsett — revokert og rotert umiddelbart. Ny token bevisst satt uten privilege separation for å matche opprinnelig oppførsel (se Åpne punkter — bør strammes inn senere) |
| Ansible-playbooks kryptert og pushet til Git | proxmox_vars.yml AES256-kryptert med Ansible Vault, vault-passord lagret lokalt på mgmt-node (/root/.vault_pass, ikke i git). Repo: github.com/Idiri/WDhomelab |
| GitHub Personal Access Token — flere iterasjoner | Første token lekket i chat (revokert). Andre token feilscopet (public read-only, deretter manglende Contents-permission). Tredje token korrekt scopet til WDhomelab med Contents: Read/write |
| Homelab-dokumentasjon flyttet til versjonskontroll | Dokumentet eksisterte tidligere kun som limt inn tekst i samtaler, ingen fil fantes. Nå docs/homelab.md i WDhomelab-repoet — eneste kilde til sannhet fremover |
| Port 3128 (spiceproxy) oppdaget eksponert og låst | pveproxy (8006) og spiceproxy (3128) fantes begge bundet til 0.0.0.0. Samme iptables-mønster som port 8006 lagt til for 3128 — ACCEPT kun tailscale0, DROP for alt annet. Persistert til /etc/iptables/rules.v4 |
| vmbr1 host-IP avklart og bevisst fjernet | 10.0.0.254 var aldri statisk konfigurert — det var en manuell ip addr add som ikke overlevde reboot (bekreftet via Tailscale-logger; IP forsvant mellom 11.–16. juli). Besluttet å la vmbr1 stå uten host-IP permanent — strukturell isolasjon (ingen rute i det hele tatt) er sterkere enn brannmurregler alene |
| OPNsense SSH-tilgang gjenopprettet | Host key hadde endret seg (sannsynligvis fra reinstallasjon i Fase 6, aldri fullt reconcilert). Ny SSH-nøkkel lagt til via WebGUI (System → Access → Users → root) |
| OPNsense SSHGuard-blokkering diagnostisert og løst | Gjentatte mislykkede SSH-forsøk trigget pf-tabellen sshlockout, som blokkerte ALL TCP-trafikk fra Kali (10.0.0.10) — inkludert port 443, ikke bare SSH. Løst via pfctl -t sshlockout -T flush fra Proxmox-konsollet (VM 101) |
| OPNsense firewall-regler auditert (pfctl -sr) | Kritisk funn: standard LAN-regel tillot ALL trafikk fra 10.0.0.x til 192.168.1.x — lab-nettet hadde ubegrenset, udokumentert rute til hjemmenettet |
| Inter-segment blokkeringsregel lagt til og verifisert | Ny LAN-regel: blokker 10.0.0.0/24 → 192.168.1.0/24, plassert korrekt over default-regelen. Verifisert fra Metasploitable: ping og curl mot 192.168.1.203 feiler nå (silent drop — 100% pakketap, ingen ICMP-feil), OPNsense LAN (10.0.0.1) og øvrige L2-noder upåvirket |
| OPNsense admin-tilgang (port 22/80/443) — forsøkt, ikke fullført | Forsøkte å begrense adminporter til kun Kali (10.0.0.10) via egne LAN-regler, deretter Floating-regler. Oppdaget at OPNsense auto-genererer ubetingede "pass from any to (self)" regler for ssh/http/https på ethvert lyttende interface, med HØYERE prioritet enn både vanlige interface-regler og Floating-regler. Besluttet å akseptere som dokumentert restrisiko (se Sikkerhetsstatus) — reell fiks krever WAN-side omstrukturering, utsatt til senere økt |

---

Bygget på Proxmox VE (192.168.1.50) for offensiv sikkerhetstesting og data engineering. Målet er et kontrollert miljø der angrepsscenarier kan kjøres uten risiko for produksjonsnettet.

Labben består av to nettverkssegmenter:

- **vmbr0 (192.168.1.x)** — hjemmenett/admin-siden
- **vmbr1 (10.0.0.x)** — isolert lab-nett, der angrep og mål lever

OPNsense fungerer som gateway og DHCP-server mellom segmentene. Kali er dual-homed og kan nå begge. Metasploitable er fullstendig isolert på 10.0.0.x, og kan siden 16. juli 2026 heller ikke lenger initiere trafikk tilbake til hjemmenettet (se inter-segment-regel under).

**Ekstern tilgang:** Tailscale er installert på Proxmox-hosten og fungerer som subnet router. All ekstern tilgang til labben (inkludert Proxmox web UI på port 8006) går gjennom Tailscale. Ingen porter er eksponert mot internett.

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

**Merk (16. juli):** Proxmox-hostens vmbr1-IP (10.0.0.254) var aldri faktisk statisk konfigurert i /etc/network/interfaces — det var en manuell `ip addr add` som ikke overlevde en reboot, og forsvant en gang mellom 11. og 16. juli uten at noen la merke til det. Etter undersøkelse er beslutningen å la vmbr1 stå uten host-IP permanent: siden OPNsense (10.0.0.1) allerede er gateway for alt lab-nett-trafikk, trengs ikke Proxmox-hosten direkte på det nettet, og fravær av IP betyr at det strukturelt ikke finnes noen rute fra 10.0.0.x til hypervisoren — sterkere enn å stole på brannmurregler alene.

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

**Merk (16. juli):** Etter lengre nedetid (fysisk flytting/rengjøring) viste noden som "offline, last seen 1d ago" i `tailscale status` fra Mac-en. Dette var ikke en Tailscale-feil, men ganske enkelt at hosten var fysisk avslått. Etter oppstart re-autentiserte Tailscale automatisk og noden kom tilbake som active.

Port 8006 og 3128 er låst med iptables — kun tilgjengelig via tailscale0:

```bash
# Disse reglene er aktive og lagret i /etc/iptables/rules.v4
iptables -I INPUT -i tailscale0 -p tcp --dport 8006 -j ACCEPT
iptables -I INPUT -p tcp --dport 8006 -j DROP
iptables -I INPUT -i tailscale0 -p tcp --dport 3128 -j ACCEPT
iptables -I INPUT -p tcp --dport 3128 -j DROP
```

- 192.168.1.50:8006 → ❌ timed out (blokkert for hele LAN-et)
- 100.108.236.64:8006 → ✅ fungerer (kun via Tailscale)
- 10.0.0.x:8006 og :3128 → ❌ strukturelt uoppnåelig (vmbr1 har ingen host-IP)
- Ingen åpne porter mot internett

### Dual-homed Kali-oppsett

```
eth0 → vmbr0 → 192.168.1.202/24   # Admin-tilgang fra Mac
eth1 → vmbr1 → 10.0.0.10/24       # Direkte tilgang til lab-nettet
```

Kali er den eneste noden som kan nå begge segmenter. Den fungerer også som SSH jump-host for å nå OPNsense. Metasploitable er kun synlig fra kali via 10.0.0.x, og kan siden 16. juli ikke lenger nå 192.168.1.x i det hele tatt.

### Ansible-filer (mgmt-node / 192.168.1.200)

| Fil | Rolle |
|---|---|
| deploy_ct.yml | Spinner opp nye LXC-containere |
| setup_web.yml | Konfigurerer Nginx på web-01 |
| hosts.ini | Inventory-fil |
| proxmox_vars.yml | Variabler for Proxmox-API — Ansible Vault-kryptert (AES256) siden 16. juli |

**Versjonskontroll (nytt 16. juli):** Playbooks er nå et git-repo, pushet til github.com/Idiri/WDhomelab. Vault-passordet ligger kun lokalt på mgmt-node (`/root/.vault_pass`, gitignored, chmod 600) — aldri i repoet.

**Kjent strukturell svakhet (ikke fikset):** Git-repoets rot er `/root` selv, ikke en dedikert undermappe. Det betyr at andre filer i /root (SSH-nøkler, bash-historikk, .git-credentials) i teorien kan havne i git ved en uforsiktig `git add -A`. `.gitignore` dekker de kjente filene i dag, men en dedikert undermappe (f.eks. `/root/ansible-homelab/`) som git-rot ville vært tryggere. Se Åpne punkter.

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
| Fase 12 — Fysisk vedlikehold | Proxmox-host flyttet bort fra ruteren og rengjort for støv. Tailscale falt fra under nedetiden | Full gjenoppretting bekreftet via Golden Path, ny baseline tatt |
| Fase 13 — Ansible/Git-hardening | Plaintext Proxmox-token oppdaget i proxmox_vars.yml, token rotert, Ansible Vault innført, playbooks pushet til GitHub | Automatiseringslaget versjonskontrollert og sikret |
| Fase 14 — Proxmox management-API lukket | Port 3128 (spiceproxy) oppdaget åpen på vmbr1, låst med iptables. vmbr1 host-IP bekreftet utilsiktet og fjernet permanent | Hypervisor strukturelt uoppnåelig fra lab-nettet |
| Fase 15 — OPNsense-tilgang gjenopprettet og auditert | SSH-nøkkel og sshlockout-blokkering løst via Proxmox-konsoll. pfctl-audit avdekket manglende inter-segment filtrering | Kritisk sikkerhetshull identifisert |
| Fase 16 — Inter-segment brannmurregel | Blokkeringsregel 10.0.0.x → 192.168.1.x lagt til og verifisert fra Metasploitable | Lab-nettet kan ikke lenger nå hjemmenettet |
| Fase 17 — OPNsense admin-tilgang (forsøk) | LAN- og Floating-regler forsøkt for å begrense adminporter til Kali. OPNsense sine auto-genererte service-regler viste seg å ha høyere prioritet enn begge | Akseptert som dokumentert restrisiko — reell fiks krever WAN-side omstrukturering |

### Kritiske lærdommer

- Aldri rediger OPNsense config.xml direkte — krevde full reinstallasjon
- OPNsense 26.1 detekterer live media basert på om ISO-enheten er koblet til — fjern med `qm set 101 --ide2 none`
- `opnsense-installer` kan kjøres fra live-shellet (option 8) — ikke prøv å fange boot-menyen
- Lim aldri inn levende hemmeligheter (API-tokens, passord) i en chat-samtale — selv midlertidig limt inn lever det videre i samtalelogger. Skriv hemmeligheter direkte inn i mål-terminalen, aldri via en AI-assistent som mellomledd
- GitHub fine-grained tokens: "Repository access" og "Permissions" må BEGGE settes eksplisitt ved opprettelse — standardvalget er ofte "Public repositories (read-only)" og "No access" per permission-kategori, og kan ikke alltid endres i etterkant via "Edit" (må da opprettes på nytt)
- OPNsense auto-genererer ubetingede tillat-regler for aktiverte tjenester (SSH/webConfigurator) på hvert lyttende interface — disse har HØYERE prioritet enn både vanlige interface-regler og Floating-regler, og kan ikke overstyres kun gjennom regelrekkefølge i GUI-en. Reell kildebegrensning krever endring av "Listen Interfaces" i System → Settings → Administration, ikke bare brannmurregler
- Gjentatte mislykkede SSH-forsøk mot OPNsense trigger SSHGuard (pf-tabellen sshlockout), som blokkerer ALL TCP-trafikk fra kildeadressen — ikke bare SSH. Løs med `pfctl -t sshlockout -T flush` fra en lokal konsoll dersom man blir låst ute
- Et konsistent 100% pakketap i ping er en pålitelig indikator på en fungerende "block/drop"-brannmurregel; curl sine feilmeldinger ("connection refused" vs "couldn't connect" vs SSL-feil) kan være misvisende og bør ikke tolkes bokstavelig uten å se rå-output fra kommandoen

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

### Baseline snapshots & backups

| Node | Type | Navn/Fil | Størrelse | Dato |
|---|---|---|---|---|
| VM 101 — OPNsense | Proxmox snapshot | baseline-1jul2026 | — | 1. juli |
| VM 300 — Metasploitable | Proxmox snapshot | baseline-1jul2026 | — | 1. juli |
| CT 200 — mgmt-node | vzdump | vzdump-lxc-200-2026_07_01-18_21_27.tar.zst | 825MB | 1. juli |
| CT 201 — web-01 | vzdump | vzdump-lxc-201-2026_07_01-18_21_41.tar.zst | 194MB | 1. juli |
| CT 202 — kali-01 | vzdump | vzdump-lxc-202-2026_07_01-18_21_46.tar.zst | 3.02GB | 1. juli |
| VM 101 — OPNsense | Proxmox snapshot | baseline-16jul2026 | — | 16. juli |
| VM 300 — Metasploitable | Proxmox snapshot | baseline-16jul2026 | — | 16. juli |
| CT 200 — mgmt-node | vzdump | vzdump-lxc-200-2026_07_16-18_06_22.tar.zst | 826MB | 16. juli |
| CT 201 — web-01 | vzdump | vzdump-lxc-201-2026_07_16-18_06_38.tar.zst | 194MB | 16. juli |
| CT 202 — kali-01 | vzdump | vzdump-lxc-202-2026_07_16-18_06_47.tar.zst | 3.02GB | 16. juli |

Alle backups lagret på Proxmox-host: `/var/lib/vz/dump/`

```bash
# Reverter VM til snapshot:
ssh proxmox 'qm rollback 101 baseline-16jul2026'
ssh proxmox 'qm rollback 300 baseline-16jul2026'

# Gjenopprett LXC fra backup:
ssh proxmox 'pct restore 200 /var/lib/vz/dump/vzdump-lxc-200-2026_07_16-18_06_22.tar.zst'

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

### Ansible-endringer (nytt 16. juli)

Alle endringer i `/root` på mgmt-node skal nå committes og pushes:

```bash
ssh mgmt
cd /root
git add <endrede filer>
git commit -m "..."
git push
```

---

## 5. Åpne punkter & neste steg

| Prioritet | Punkt | Status |
|---|---|---|
| ✅ Ferdig | iptables port 8006 låst til tailscale0 og lagret til /etc/iptables/rules.v4 | Gjort 1. juli |
| ✅ Ferdig | SSH hardening — PasswordAuthentication no på alle noder | Gjort 1. juli |
| ✅ Ferdig | Baseline snapshot tatt — VM 101, 300 + vzdump CT 200, 201, 202 | Gjort 1. juli, fornyet 16. juli |
| ✅ Ferdig | Push Ansible-playbooks til Git for backup | Gjort 16. juli — Ansible Vault-kryptert, GitHub: Idiri/WDhomelab |
| ✅ Ferdig | Proxmox REST API/spiceproxy eksponert på vmbr1 | Gjort 16. juli — port 3128 låst, vmbr1 har ingen host-IP |
| ✅ Ferdig | Dokumenter OPNsense firewall-regler (inter-segment policy vmbr0↔vmbr1) | Gjort 16. juli — se pfctl-audit i denne loggen |
| ✅ Ferdig | Legg til OPNsense-regel: blokker 10.0.0.x → 192.168.1.x | Gjort 16. juli — verifisert fra Metasploitable |
| 🔴 Høy | Bytt fra root SSH til dedikerte brukere på alle noder | Ikke gjort |
| 🔴 Høy | Begrens OPNsense admin-tilgang (port 22/80/443 på LAN) til kun Kali | Forsøkt 16. juli, ikke løst — OPNsense sine auto-genererte service-regler overstyrer både interface- og Floating-regler. Krever WAN-side omstrukturering (endre Listen Interfaces + eksplisitt WAN-regel for Kalis WAN-IP) |
| 🟠 Medium | Skaler ned Ansible API-token til minste privilegium | Nytt 16. juli — token har i dag full root-ekvivalent tilgang (privilege separation avskrudd for å matche gammel oppførsel). Bør erstattes med egen PVE-rolle med kun nødvendige rettigheter |
| 🟠 Medium | Restrukturer Ansible git-repo — flytt bort fra /root som repo-rot | Nytt 16. juli — /root som git-rot er en unødvendig blast-radius-risiko. Flytt til f.eks. /root/ansible-homelab/ |
| 🟠 Medium | Offensiv testing av Nginx 1.22.1 på web-01 | Ikke startet |
| 🟡 Lav | Legg til SIEM (Wazuh eller Security Onion) for nettverkssynlighet | Ikke startet |
| 🟡 Lav | Sett opp reverse proxy foran web-01 | Ikke startet |
| 🟡 Lav | Snapshot Metasploitable før hver offensive økt (se Golden Path) | Rutine etablert |
| 🟡 Lav | Pin/dokumenter Metasploitable-versjon | Ikke gjort |
| 🟡 Lav | Automatiser snapshot-rotasjon med retention-policy | Ikke startet |
| 🟡 Lav | Sårbarhetsskann-baseline (OpenVAS/nmap --script vuln) for Metasploitable + web-01 | Ikke startet |
| 🟡 Lav | Automatiser OPNsense config.xml-backup | Ikke startet |
| 🟡 Lav | DNS for lab-nettet (dnsmasq/Pi-hole på vmbr1) | Ikke startet |

---

## 6. Sikkerhetsstatus

| Område | Status | Notat |
|---|---|---|
| Internett-eksponering | ✅ Ingen | Ingen åpne porter mot internett |
| Nettverkssegmentering | ✅ OK | vmbr0 / vmbr1 med OPNsense mellom |
| Inter-segment filtrering (10.0.0.x → 192.168.1.x) | ✅ Sikret | Blokkeringsregel aktiv og verifisert 16. juli — lab-nettet kan ikke lenger nå hjemmenettet |
| Ekstern tilgang | ✅ Tailscale | Subnet router på Proxmox-host |
| Proxmox web UI | ✅ Låst | iptables blokkerer 8006 på LAN — kun 100.108.236.64:8006 via Tailscale |
| Proxmox REST API/spiceproxy på vmbr1 | ✅ Sikret | vmbr1 har ingen host-IP — ingen rute fra 10.0.0.x til hypervisoren. Port 8006 og 3128 begge låst til tailscale0 via iptables |
| SSH-autentisering | ✅ Bekreftet | PasswordAuthentication no på alle noder — verifisert 1. juli |
| SSH-bruker | ⚠️ Root | Bør byttes til dedikerte brukere |
| OPNsense admin-porter (22/80/443) på LAN | ⚠️ Åpne for hele 10.0.0.x | Alle lab-nett-noder kan nå OPNsense sin GUI/SSH, ikke bare Kali. Kompenserende kontroll: nøkkelbasert SSH + påloggingskrav på GUI. Reell fiks krever WAN-side omstrukturering (se Åpne punkter) |
| iptables persistens | ✅ Bekreftet | Lagret til /etc/iptables/rules.v4 — overlever reboot |
| Ansible API-token privilegier | ⚠️ For bredt | Token har full root-ekvivalent tilgang på Proxmox — bør erstattes med minste-privilegium-rolle |
| Git/secrets-hygiene | ✅ Sikret | proxmox_vars.yml Ansible Vault-kryptert, .git-credentials og .gitconfig gitignored, ingen klartekst-hemmeligheter i git-historikk |
| Logging/SIEM | ❌ Mangler | Ingen synlighet på nettverksnivå |
