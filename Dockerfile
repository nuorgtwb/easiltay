FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    DISPLAY=:1 \
    HOME=/root \
    XRAY_VERSION=1.8.24

RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-goodies xfce4-terminal \
    dbus-x11 x11vnc novnc websockify \
    supervisor curl ca-certificates unzip jq openssl procps \
    fonts-dejavu fonts-noto-core \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/xray /etc/xray /var/log/supervisor /run/dbus
RUN curl -fsSL "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip" -o /tmp/xray.zip \
    && unzip -q /tmp/xray.zip -d /opt/xray \
    && chmod +x /opt/xray/xray \
    && rm /tmp/xray.zip

COPY xray/config.json /etc/xray/config.template.json
COPY scripts/generate-xray-config.sh /usr/local/bin/generate-xray-config
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /usr/local/bin/generate-xray-config /usr/local/bin/entrypoint.sh

EXPOSE 8080

CMD ["/usr/local/bin/entrypoint.sh"]
