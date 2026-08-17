# Frequently Asked Questions

English | [简体中文](FAQ.zh-CN.md)

## What is open sourced today?

This repository includes the Android client source, build configuration, test fixtures, documentation, and the first-party hardened CHAKEN trusted-call SDK authorized for public redistribution. It does not include backend source, an admin console, databases, or production operations configuration.

## Can I build an APK after cloning?

With JDK 11, Android SDK 33, and a configured Android SDK path, run `:app:assembleProdDebug` to build a debug APK connected to the default hosted service. Distribution builds require your own signing identity. See [Build and configuration](BUILD_AND_CONFIGURATION.md).

## Does building the APK grant access to every online service?

No. Hosted-service access, accounts, SMS, telephony, models, maps, storage, quotas, and regional capabilities are separate from the Apache-2.0 source license and follow the actual service policy.

## Is the backend open source? Can I fully self-host?

The backend is not currently open source, and this repository does not provide a complete self-hosting package. The `local` variant can point to an independently implemented compatible service, but developers must implement the required HTTPS, SSE, WebSocket, authentication, task, calling, and history contracts themselves.

## Where are model keys, SMS credentials, and SIP accounts?

Those credentials belong only in controlled server-side environments. They must not be embedded in Android source, sample properties, APKs, or logs. Values included in an APK must be explicitly approved for client distribution, revocable, and least-privileged.

## Can I develop a Call Skill today?

Not yet. Call Skills are a public roadmap direction. The current repository publishes the vision, conceptual model, and contribution path—not an executable SDK. Status changes will appear in the [roadmap](ROADMAP.en.md).

## What can I contribute now?

Contributions are welcome for Android client features, reliability, automated tests, documentation, translations, privacy and security, and Call Skill scenario proposals that include inputs, outputs, risks, and test cases.

## Why might a feature be unavailable in my build?

Common causes include hosted capability policy, account or quota limits, telephony and regional restrictions, excluded optional commercial SDKs, device permissions, network conditions, and third-party outages. Check [Known issues](KNOWN_ISSUES.md) and client logs first.

## Can Phone Agent be used for bulk marketing calls?

Do not use this project for harassment, spam calling, deception, or unauthorized impersonation. Real calls, recordings, contacts, location, translation, and voice cloning must follow applicable law, carrier rules, provider terms, and required consent and notice.
