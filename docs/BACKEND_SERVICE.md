# 后台服务边界 / Backend Service Boundary

## 中文

本仓库不包含后台源码。默认客户端连接：

```text
https://chaken.ai/aiassistant-api/
```

托管后台负责短信认证、账号会话、任务理解、模型调用、地图查询、SIP 资源租约、电话任务编排、通话事件、记录和 OTA 元数据。相关账号、API Key、Secret、SIP 密码和生产数据只存在于服务端受控环境。

Apache-2.0 只授予本仓库终端源码的许可，不自动授予托管服务、模型额度、电话线路、短信额度、域名、商标或生产账号的使用权。服务可能根据合规、容量、区域、成本或运营策略调整。

自定义服务可以通过 `serverBaseUrl` 接入，但必须自行实现客户端使用的 HTTPS、SSE、WebSocket、认证、任务、通话和记录契约。本仓库不承诺第三方实现与官方托管服务完全兼容。

## English

This repository does not contain backend source. The default client endpoint is:

```text
https://chaken.ai/aiassistant-api/
```

The hosted backend handles SMS authentication, sessions, task understanding, model calls, map queries, SIP leases, call orchestration, call events, history, and OTA metadata. Accounts, API keys, secrets, SIP passwords, and production data remain in controlled server-side systems.

Apache-2.0 licenses only the client source in this repository. It does not grant rights to hosted-service capacity, model quotas, telephone routes, SMS quotas, domains, trademarks, or production accounts. Service behavior may change for compliance, capacity, regional, cost, or operational reasons.

An independently implemented service can be selected with `serverBaseUrl`, but it must implement the HTTPS, SSE, WebSocket, authentication, task, calling, and history contracts used by the client. This project does not guarantee third-party compatibility with the official hosted service.
