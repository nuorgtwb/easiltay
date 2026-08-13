#!/usr/bin/env bash
set -euo pipefail

PUBLIC_HOST="${PUBLIC_HOST:-${RAILWAY_PUBLIC_DOMAIN:-}}"
TCP_HOST="${RAILWAY_TCP_PROXY_DOMAIN:-}"
TCP_PORT="${RAILWAY_TCP_PROXY_PORT:-}"
NODE_OUTPUT_MODE="${NODE_OUTPUT_MODE:-base64}"
WS_PATH="${WS_PATH:-/vless-ws}"
XHTTP_PATH="${XHTTP_PATH:-/xray-xhttp}"
REALITY_SERVER_NAME="${REALITY_SERVER_NAME:-www.cloudflare.com}"
REALITY_SHORT_ID="${REALITY_SHORT_ID:-}"
REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:-}"

if [[ -z "$PUBLIC_HOST" ]]; then
  PUBLIC_HOST="localhost"
fi

WS_URI="vless://${XRAY_UUID}@${PUBLIC_HOST}:443?encryption=none&security=tls&type=ws&host=${PUBLIC_HOST}&sni=${PUBLIC_HOST}&path=${WS_PATH//\//%2F}#easiltay-ws-tls"

REALITY_URI=""
if [[ -n "$TCP_HOST" && -n "$TCP_PORT" ]]; then
  REALITY_URI="vless://${XRAY_UUID}@${TCP_HOST}:${TCP_PORT}?encryption=none&security=reality&type=xhttp&path=${XHTTP_PATH//\//%2F}&sni=${REALITY_SERVER_NAME}&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&flow=xtls-rprx-vision#easiltay-xhttp-reality"
fi

b64() { printf '%s' "$1" | base64 -w0; }
WS_B64="$(b64 "$WS_URI")"
REALITY_B64=""
[[ -n "$REALITY_URI" ]] && REALITY_B64="$(b64 "$REALITY_URI")"

cat > /var/www/status/nodes.json <<EOF
{
  "mode": "${NODE_OUTPUT_MODE}",
  "web": "https://${PUBLIC_HOST}",
  "vless_ws_tls_base64": "${WS_B64}",
  "vless_xhttp_reality_base64": "${REALITY_B64}",
  "reality_public_key": "${REALITY_PUBLIC_KEY}",
  "reality_server_name": "${REALITY_SERVER_NAME}",
  "reality_short_id": "${REALITY_SHORT_ID}",
  "tcp_proxy": "${TCP_HOST}:${TCP_PORT}",
  "notes": [
    "Base64 is encoding, not encryption. It prevents casual log readability but does not protect secrets from anyone who can read the logs.",
    "VLESS + WebSocket + REALITY is not a supported Xray transport combination; the web entry uses VLESS + WebSocket + TLS through Railway HTTPS.",
    "XHTTP + REALITY requires a Railway TCP Proxy (or another raw TCP path) to be publicly reachable."
  ]
}
EOF

# Never print the UUID/private key or plaintext URI to logs.
echo "[easiltay] Node exports (Base64 only):"
echo "[easiltay] VLESS WS + TLS: ${WS_B64}"
if [[ -n "$REALITY_B64" ]]; then
  echo "[easiltay] VLESS XHTTP + REALITY: ${REALITY_B64}"
else
  echo "[easiltay] VLESS XHTTP + REALITY: not externally addressable yet; enable Railway TCP Proxy for internal port ${XRAY_REALITY_PORT:-10003}."
fi
echo "[easiltay] Reality public key: ${REALITY_PUBLIC_KEY}"
echo "[easiltay] Reality short ID: ${REALITY_SHORT_ID}"
