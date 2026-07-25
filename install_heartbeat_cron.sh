#!/bin/sh
set -eu
chmod 755 /root/metasploitable_heartbeat.sh
cp /root/metasploitable-heartbeat.service /etc/systemd/system/metasploitable-heartbeat.service
cp /root/metasploitable-heartbeat.timer /etc/systemd/system/metasploitable-heartbeat.timer
systemctl daemon-reload
systemctl enable --now metasploitable-heartbeat.timer
