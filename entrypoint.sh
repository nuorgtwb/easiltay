#!/usr/bin/env bash
set -euo pipefail

mkdir -p /run/dbus /var/run/supervisor /var/log/supervisor /etc/xray

if [[ -z "${XRAY_UUID:-}" ]]; then
  XRAY_UUID="$(cat /proc/sys/kernel/random/uuid)"
  echo "Generated XRAY_UUID=${XRAY_UUID}"
fi
export XRAY_UUID

if [[ -z "${XRAY_PORT:-}" ]]; then
  XRAY_PORT=443
fi
export XRAY_PORT

/usr/local/bin/generate-xray-config

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
