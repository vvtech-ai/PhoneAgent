# Security Policy / 安全策略

## Reporting / 报告方式

Do not disclose an unpatched vulnerability in a public issue. Send a private report to the repository owner or the security contact published by the project host. Include the affected version, reproduction steps, impact, and a minimal proof of concept. Do not include production credentials or unrelated personal data.

未修复的安全漏洞请勿提交到公开 Issue。请通过仓库所有者或项目托管页公布的安全联系方式私下报告，并包含受影响版本、复现步骤、影响和最小证明。不得附带生产密钥或无关个人信息。

## Credential rules / 凭据规则

- Never commit model API keys, SMS credentials, SIP passwords, map keys, tokens, signing files, real verification codes, or production logs.
- APKs are untrusted distribution artifacts: any value embedded in `BuildConfig`, resources, assets, native libraries, or bytecode can be extracted.
- Use server-side credentials, short-lived user tokens, revocable client identifiers, and least privilege.
- Rotate any credential immediately if it appears in Git history, CI logs, an APK, or an issue attachment.

- 禁止提交模型 API Key、短信凭据、SIP 密码、地图 Key、Token、签名文件、真实验证码或生产日志。
- APK 是不可信分发物：写入 `BuildConfig`、资源、Assets、原生库或字节码的值都可能被提取。
- 使用服务端凭据、短期用户 Token、可撤销客户端标识和最小权限。
- 凭据一旦进入 Git 历史、CI 日志、APK 或 Issue 附件，应立即轮换。
