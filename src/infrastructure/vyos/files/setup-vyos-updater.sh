#!/bin/bash
set -e
cp /config/scripts/vyos-updater.service /etc/systemd/system/vyos-updater.service
cp /config/scripts/vyos-updater.timer /etc/systemd/system/vyos-updater.timer
systemctl enable vyos-updater.timer
