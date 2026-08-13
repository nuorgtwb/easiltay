# easiltay

Railway 上的 Ubuntu Web Desktop + Xray 实验项目。

## 第一版架构

- Ubuntu 24.04 + XFCE
- x11vnc + noVNC，浏览器直接进入 Ubuntu 桌面
- Nginx 作为 Railway HTTP 单入口
- `/vless-ws` 反代到内部 Xray WebSocket 入站
- `/status/` 提供浏览器状态页
- Xray Core 26.7.28
- 启动时自动生成 UUID（如果未提供）
- 启动时自动生成 REALITY X25519 密钥对和 short ID
- Xray 配置启动时生成并用 `xray -test` 校验

当前 Xray 组合：

1. **VLESS + WebSocket + TLS（Railway HTTPS）**：浏览器入口和 WS 共用 Railway HTTP/HTTPS 入口。
2. **VLESS + TCP + TLS**：需要真实证书，并建议使用 Railway TCP Proxy 暴露内部 TCP 端口。
3. **VLESS + XHTTP + REALITY**：需要 Railway TCP Proxy 或其它 raw TCP 入口。

注意：当前 Xray 官方传输组合表明确指出 **WebSocket + REALITY 不支持**，所以这里将 WebSocket 方案实现为 WebSocket + TLS，而 XHTTP + REALITY 单独实现。citeturn2search4turn1search8

## Railway 部署

Railway 的 HTTP 公网入口使用服务的 `$PORT`；Railway 也提供 TCP Proxy，可以把服务内部的 TCP 端口映射到公网。citeturn3search1turn3search0

1. 将仓库连接到 Railway。
2. 使用 `Dockerfile` 构建。
3. Generate Domain，确认 HTTP 服务已经可访问。
4. 访问：

```text
https://<你的-railway-域名>/status/
```

或直接进入：

```text
https://<你的-railway-域名>/vnc.html
```

### 推荐环境变量

```text
# 建议通过 Railway Variables/Secrets 提供
XRAY_UUID=<UUID>

# WebSocket 内部端口
XRAY_WS_PORT=10001

# TCP + TLS 内部端口（需要证书）
XRAY_TLS_PORT=10002

# XHTTP + REALITY 内部端口；创建 Railway TCP Proxy 时指向这个端口
XRAY_REALITY_PORT=10003

REALITY_TARGET=www.cloudflare.com:443
REALITY_SERVER_NAME=www.cloudflare.com
REALITY_SHORT_ID=<可选，不填自动生成>
REALITY_PRIVATE_KEY=<可选，不填自动生成>

WS_PATH=/vless-ws
XHTTP_PATH=/xray-xhttp
XRAY_LOG_LEVEL=warning
NODE_OUTPUT_MODE=base64
```

Railway 会自动提供 `RAILWAY_PUBLIC_DOMAIN`。如果启用了 TCP Proxy，还会提供 `RAILWAY_TCP_PROXY_DOMAIN`、`RAILWAY_TCP_PROXY_PORT` 和 `RAILWAY_TCP_APPLICATION_PORT`。citeturn3search3

### TCP Proxy

要测试 XHTTP + REALITY：

1. 在 Railway Service → Settings → Networking 创建 TCP Proxy。
2. 将 TCP Proxy 的 application/internal port 指向 `10003`，或者把 `XRAY_REALITY_PORT` 设置成 Railway 给出的 application port。
3. 部署后重新查看 `/status/` 或 Railway Logs。

Railway 官方说明 TCP Proxy 会生成独立的公网域名和端口，并把该 TCP 流量转发到指定内部端口。HTTP 和 TCP 可以同时暴露在同一个 Service 上。citeturn3search0

## 节点日志

容器启动后会在日志中输出：

- VLESS + WS + TLS 的 Base64 节点
- VLESS + XHTTP + REALITY 的 Base64 节点（如果已配置 TCP Proxy）
- REALITY public key
- REALITY short ID

默认**不会把完整明文 VLESS URI 写入日志**。

### 关于 Base64

Base64 **不是加密**。它只能避免节点 URI 在日志中以明文直接出现，不能防止拥有日志访问权限的人还原节点。因此 Railway Logs、`/status/` 和 Base64 节点本身都应当视为敏感信息。

如果需要真正防止泄露，应使用 Railway 的 Sealed Variables/Secrets，并进一步增加状态页认证；不要依赖 Base64。Railway 官方也建议将密钥、密码等敏感变量作为 secrets 管理。citeturn3search9

## 状态页

```text
/status/
```

状态页检查：

- Web 服务健康状态
- Ubuntu Web Desktop 入口
- Base64 节点字符串
- REALITY public key / short ID
- TCP Proxy 状态

## Xray 版本

当前 Dockerfile 使用 Xray Core **v26.7.28**。截至本项目当前开发时间，官方 GitHub release 页面显示 v26.7.28 为最新发布版本，但官方 release 页面将其标记为 pre-release；如果生产环境要求严格稳定版，可以将 `XRAY_VERSION` 固定到最新 stable tag。citeturn0search1turn0search4

## 安全说明

不要把 UUID、REALITY private key、TLS private key 或完整节点 URI 写入 Git。

生产环境建议：

- Railway Sealed Variables/Secrets
- 不公开 `/status/`
- 不把日志权限给无关人员
- REALITY `target` 使用自己确认安全、稳定的目标站点
- 不要把 REALITY 配置成开放式端口转发器

Xray 官方特别提醒，REALITY 鉴权失败的流量会转发到 `target`，因此错误选择 target 可能导致服务被滥用。citeturn5search0
