#!/usr/bin/env bash
set -euo pipefail

mkdir -p /run/dbus /var/run/supervisor /var/log/supervisor /etc/xray /var/lib/easiltay

if [[ -z "${XRAY_UUID:-}" ]]; then
  XRAY_UUID="$(/opt/xray/xray uuid)"
  echo "[easiltay] XRAY_UUID was not supplied; generated a new UUID for this deployment."
fi

if ! [[ "$XRAY_UUID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]; then
  echo "[easiltay] ERROR: XRAY_UUID is not a valid UUID." >&2
  exit 1
fi

export XRAY_UUID
export WEB_PORT="${PORT:-8080}"
export XRAY_WS_PORT="${XRAY_WS_PORT:-10001}"
export XRAY_TLS_PORT="${XRAY_TLS_PORT:-10002}"
export XRAY_REALITY_PORT="${XRAY_REALITY_PORT:-${RAILWAY_TCP_APPLICATION_PORT:-10003}}"
export XRAY_LOG_LEVEL="${XRAY_LOG_LEVEL:-warning}"
export NODE_OUTPUT_MODE="${NODE_OUTPUT_MODE:-base64}"

/usr/local/bin/generate-xray-config
/usr/local/bin/render-status

sed "s/listen 8080;/listen ${WEB_PORT};/" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
nginx -t

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
