# WDhomelab

Ansible-styrt konfigurasjon for et isolert hjemmelab bygget på Proxmox VE — segmentert
nettverk (vmbr0 admin / vmbr1 isolert lab), OPNsense som gateway, Homepage-dashboard
med Uptime Kuma-overvåking, ekstern tilgang via Tailscale. Dette er den private
arbeidsrepoen; se [`docs/homelab.md`](docs/homelab.md) for fullstendig arkitektur,
changelog og driftsdokumentasjon — det er eneste kilde til sannhet for denne labben.

For en offentlig, sanitert portefølje-versjon (arkitekturdiagram, skjermbilde, "hva
dette demonstrerer"), se [github.com/Idiri/homelab](https://github.com/Idiri/homelab).

## Repo-rot = /root (mgmt-node)

Denne repoen er rotet direkte i `/root` på mgmt-node (192.168.1.200), ikke en dedikert
undermappe — se "Kjent strukturell svakhet" i docs/homelab.md. **Bruk aldri
`git add -A` eller `git add .`** i denne repoen; legg alltid til filer ved navn.

## Innhold (kort)

| Fil/mønster | Rolle |
|---|---|
| `deploy_*.yml` | Oppretter nye LXC-containere (host-exec / pct create over ssh) |
| `setup_*.yml` | Konfigurerer en allerede opprettet container/vert |
| `*_vars.yml` | Ansible Vault-krypterte variabler (AES256) — aldri klartekst i git |
| `services.yaml` | Homepage-dashbordets tile-/widget-konfigurasjon |
| `services.sanitized.yaml` + `sanitize.sed` | Sanitert variant av services.yaml for offentlige skjermbilder — se README i den offentlige repoen |
| `custom.css` | Homepage-tema (mørk bakgrunn, vmbr0/vmbr1-gruppevisning, statusfarger) |
| `docs/homelab.md` | Full driftsdokumentasjon — arkitektur, changelog, Golden Path, Sikkerhetsstatus |

## Kom i gang

Se seksjon 4 ("Golden Path for drift") i `docs/homelab.md` for helsesjekk-kommandoer,
baseline-gjenoppretting og daglig drift.

## Vault-passord

`/root/.vault_pass` — lokal på mgmt-node, gitignored, chmod 600. Aldri i git.
