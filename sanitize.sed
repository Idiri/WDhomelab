# sanitize.sed — mechanical part of producing services.sanitized.yaml from services.yaml
#
# Usage:
#   sed -f sanitize.sed services.yaml > services.sanitized.yaml
#
# Real host IPs -> RFC 5737 documentation-range IPs (never route on a real network),
# and Proxmox token placeholders -> obviously-fake demo values.
#
# NOT fully automatic: after running this, a few free-text description fields still
# say "vmbr0"/"vmbr1", "10.0.0.x"/"192.168.1.x", or spell out the SSH tunnel command
# with a real IP inline (e.g. the OPNsense and Isolasjon tile descriptions). Those were
# reworded by hand in services.sanitized.yaml to generic "admin-segment"/"lab-segment"
# language — sed alone can't safely rewrite prose without also mangling it.

s/192\.168\.1\.50/203.0.113.10/g
s/192\.168\.1\.205/203.0.113.20/g
s/192\.168\.1\.200/203.0.113.11/g
s/192\.168\.1\.203/203.0.113.12/g
s/192\.168\.1\.202/198.51.100.10/g
s#https://10\.0\.0\.1#https://198.51.100.1#g
s/10\.0\.0\.176/198.51.100.176/g
s/{{HOMEPAGE_VAR_PROXMOX_TOKEN_ID}}/demo-token-id/g
s/{{HOMEPAGE_VAR_PROXMOX_TOKEN_SECRET}}/demo-token-secret/g
s/{{HOMEPAGE_VAR_PROXMOX_AUTH_HEADER}}/demo-auth-header/g
