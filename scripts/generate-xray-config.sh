#!/usr/bin/env bash
set -euo pipefail

: "${XRAY_UUID:?XRAY_UUID is required}"
XRAY_PORT="${XRAY_PORT:-443}"
XRAY_LOG_LEVEL="${XRAY_LOG_LEVEL:-warning}"

cat > /etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "${XRAY_LOG_LEVEL}"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${XRAY_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {"id": "${XRAY_UUID}", "flow": ""}
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp"
      },
      "tag": "vless-tcp"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": []
  }
}
EOF

/opt/xray/xray -test -config /etc/xray/config.json
