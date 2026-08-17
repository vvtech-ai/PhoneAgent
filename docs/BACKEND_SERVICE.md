# Backend Service Boundary

This repository does not contain backend source. The default client endpoint is:

```text
https://chaken-ai.vvtech.tech/aiassistant-api/
```

The hosted backend handles SMS authentication, sessions, task understanding, model calls, map queries, SIP leases, call orchestration, call events, history, and OTA metadata. Accounts, API keys, secrets, SIP passwords, and production data remain in controlled server-side systems.

Apache-2.0 licenses only the client source in this repository. It does not grant rights to hosted-service capacity, model quotas, telephone routes, SMS quotas, domains, trademarks, or production accounts. Service behavior may change for compliance, capacity, regional, cost, or operational reasons.

An independently implemented service can be selected with `serverBaseUrl`, but it must implement the HTTPS, SSE, WebSocket, authentication, task, calling, and history contracts used by the client. This project does not guarantee third-party compatibility with the official hosted service.
