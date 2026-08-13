#!/usr/bin/env bash
set -euo pipefail

: "${XRAY_UUID:?XRAY_UUID is required}"
WS_PORT="${XRAY_WS_PORT:-10001}"
TLS_PORT="${XRAY_TLS_PORT:-10002}"
REALITY_PORT="${XRAY_REALITY_PORT:-10003}"
XRAY_LOG_LEVEL="${XRAY_LOG_LEVEL:-warning}"
REALITY_TARGET="${REALITY_TARGET:-www.cloudflare.com:443}"
REALITY_SERVER_NAME="${REALITY_SERVER_NAME:-www.cloudflare.com}"
REALITY_SHORT_ID="${REALITY_SHORT_ID:-$(openssl rand -hex 8)}"
WS_PATH="${WS_PATH:-/vless-ws}"
XHTTP_PATH="${XHTTP_PATH:-/xray-xhttp}"

mkdir -p /etc/xray /var/lib/easiltay

if [[ -z "${REALITY_PRIVATE_KEY:-}" ]]; then
  REALITY_PRIVATE_KEY="$(/opt/xray/xray x25519 | awk -F': ' '/Private key/ {print $2; exit}')"
fi
if [[ -z "${REALITY_PRIVATE_KEY:-}" ]]; then
  echo "[easiltay] ERROR: failed to generate REALITY private key." >&2
  exit 1
fi
REALITY_PUBLIC_KEY="$(/opt/xray/xray x25519 -i "$REALITY_PRIVATE_KEY" | awk -F': ' '/Public key/ {print $2; exit}')"
if [[ -z "${REALITY_PUBLIC_KEY:-}" ]]; then
  echo "[easiltay] ERROR: failed to derive REALITY public key." >&2
  exit 1
fi

# Railway Variables can carry multiline PEM values. Materialize them only inside the container.
if [[ -n "${TLS_CERT_PEM:-}" && -n "${TLS_KEY_PEM:-}" ]]; then
  printf '%s\n' "$TLS_CERT_PEM" > /etc/xray/runtime.crt
  printf '%s\n' "$TLS_KEY_PEM" > /etc/xray/runtime.key
  chmod 600 /etc/xray/runtime.key
  TLS_CERT_FILE=/etc/xray/runtime.crt
  TLS_KEY_FILE=/etc/xray/runtime.key
fi

TLS_ENABLED=false
if [[ -n "${TLS_CERT_FILE:-}" && -n "${TLS_KEY_FILE:-}" && -f "${TLS_CERT_FILE}" && -f "${TLS_KEY_FILE}" ]]; then
  TLS_ENABLED=true
fi

export WS_PATH XHTTP_PATH REALITY_TARGET REALITY_SERVER_NAME REALITY_SHORT_ID
export REALITY_PRIVATE_KEY REALITY_PUBLIC_KEY TLS_ENABLED
export XRAY_UUID XRAY_WS_PORT XRAY_TLS_PORT XRAY_REALITY_PORT XRAY_LOG_LEVEL
export TLS_CERT_FILE TLS_KEY_FILE

python3 - <<'PY'
import json, os

u=os.environ['XRAY_UUID']
ws_port=int(os.environ['XRAY_WS_PORT'])
tls_port=int(os.environ['XRAY_TLS_PORT'])
reality_port=int(os.environ['XRAY_REALITY_PORT'])
ws_path=os.environ['WS_PATH']
xhttp_path=os.environ['XHTTP_PATH']
reality_target=os.environ['REALITY_TARGET']
reality_sni=os.environ['REALITY_SERVER_NAME']
reality_private=os.environ['REALITY_PRIVATE_KEY']
short_id=os.environ['REALITY_SHORT_ID']

inbounds=[
  {
    'tag':'vless-ws', 'listen':'127.0.0.1', 'port':ws_port, 'protocol':'vless',
    'settings':{'clients':[{'id':u}], 'decryption':'none'},
    'streamSettings':{'network':'ws','security':'none','wsSettings':{'path':ws_path}}
  },
  {
    'tag':'vless-xhttp-reality', 'listen':'0.0.0.0', 'port':reality_port, 'protocol':'vless',
    'settings':{'clients':[{'id':u,'flow':'xtls-rprx-vision'}], 'decryption':'none'},
    'streamSettings':{
      'network':'xhttp','security':'reality',
      'xhttpSettings':{'path':xhttp_path,'mode':'auto'},
      'realitySettings':{
        'show':False,'target':reality_target,
        'serverNames':[reality_sni], 'privateKey':reality_private,
        'shortIds':[short_id]
      }
    }
  }
]

if os.environ.get('TLS_ENABLED') == 'true':
  inbounds.append({
    'tag':'vless-tls','listen':'0.0.0.0','port':tls_port,'protocol':'vless',
    'settings':{'clients':[{'id':u}], 'decryption':'none'},
    'streamSettings':{
      'network':'tcp','security':'tls',
      'tlsSettings':{
        'alpn':['h2','http/1.1'],
        'certificates':[{'certificateFile':os.environ['TLS_CERT_FILE'],'keyFile':os.environ['TLS_KEY_FILE']}]
      }
    }
  })

cfg={
  'log':{'loglevel':os.environ['XRAY_LOG_LEVEL']},
  'inbounds':inbounds,
  'outbounds':[{'protocol':'freedom','tag':'direct'},{'protocol':'blackhole','tag':'blocked'}]
}
with open('/etc/xray/config.json','w') as f:
  json.dump(cfg,f,indent=2)
PY

/opt/xray/xray -test -config /etc/xray/config.json
