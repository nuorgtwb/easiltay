# easiltay

Railway 上的 Ubuntu Web Desktop + Xray 实验项目。

## 当前版本

第一版先验证基础链路：

- Ubuntu 24.04
- XFCE 桌面
- x11vnc + noVNC
- 浏览器通过 Railway HTTP 服务访问桌面
- Xray Core
- VLESS + TCP 基础入站作为第一阶段验证

Reality、TLS、WS、XHTTP 会在 Railway 网络模型验证通过后继续加入，避免把尚未验证的公网入口模型直接写死。

## Railway 部署

1. 将仓库连接到 Railway。
2. 使用仓库中的 `Dockerfile` 构建。
3. Railway 会自动提供 `$PORT`，桌面 Web 服务默认监听 `8080`；如果 Railway 要求动态端口，可将 `PORT` 映射到应用监听端口并在后续版本统一处理。
4. 建议先使用 Railway 生成的域名验证 noVNC。
5. 部署完成后访问：

```text
https://<你的-railway-域名>/vnc.html
```

### 推荐环境变量

```text
XRAY_UUID=<你的 UUID>
XRAY_PORT=<Railway 可用的 Xray TCP 端口>
XRAY_LOG_LEVEL=warning
```

如果没有设置 `XRAY_UUID`，容器会在启动时临时生成 UUID；生产环境不建议依赖这种行为。

## 浏览器桌面

noVNC 会连接容器内部的 x11vnc，再由 XFCE 提供 Ubuntu 桌面。

首次验证建议：

1. 先确认 `/vnc.html` 能打开。
2. 确认 XFCE 桌面可以正常显示。
3. 再验证 Xray 进程和监听端口。
4. 最后逐个加入 VLESS + WS、VLESS + TCP + TLS、VLESS + XHTTP + Reality。

## Xray

Xray 二进制版本由 `Dockerfile` 中的 `XRAY_VERSION` 控制。升级时应同时验证配置语法和 Railway 网络行为。

## 安全说明

不要把 UUID、Reality private key 或 TLS private key 写入 Git。生产部署应通过 Railway Variables/Secrets 注入。
