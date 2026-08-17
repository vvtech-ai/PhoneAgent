# Security Policy

## Reporting

Do not disclose an unpatched vulnerability in a public issue. Send a private report to the repository owner or the security contact published by the project host. Include the affected version, reproduction steps, impact, and a minimal proof of concept. Do not include production credentials or unrelated personal data.

## Credential rules

- Never commit model API keys, SMS credentials, SIP passwords, map keys, tokens, signing files, real verification codes, or production logs.
- APKs are untrusted distribution artifacts: any value embedded in `BuildConfig`, resources, assets, native libraries, or bytecode can be extracted.
- Use server-side credentials, short-lived user tokens, revocable client identifiers, and least privilege.
- Rotate any credential immediately if it appears in Git history, CI logs, an APK, or an issue attachment.
