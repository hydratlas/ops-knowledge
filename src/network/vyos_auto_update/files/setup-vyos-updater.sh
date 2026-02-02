#!/bin/bash
set -e
cp /config/scripts/vyos-updater.service /etc/systemd/system/vyos-updater.service
cp /config/scripts/vyos-updater.timer /etc/systemd/system/vyos-updater.timer
systemctl daemon-reload
systemctl enable vyos-updater.timer
systemctl start vyos-updater.timer
