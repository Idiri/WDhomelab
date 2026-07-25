#!/bin/sh
set -eu
. /root/.kuma.env.tmp
export KUMA_ADMIN_USER KUMA_ADMIN_PASS
/opt/uptime-kuma/venv/bin/python3 /root/kuma_setup.py
