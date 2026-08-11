# Phone Agent Project Introduction

English | [简体中文](PROJECT_INTRODUCTION.zh-CN.md)

## Positioning

Phone Agent is a mobile intelligent client for phone-based tasks. It connects the full workflow—describing a need, understanding and confirming the task, preparing and executing a call, and reviewing the result—so users can handle restaurant reservations, meeting notifications, coordination, real-time translation, and similar scenarios with natural language.

This open-source project provides the Android client only. Model inference, SMS authentication, task orchestration, map search, SIP calling, and data services run on a deployed hosted backend whose source is not included.

![Software module structure](images/architecture.png)

## User journey

### 1. Sign in and prepare

Users sign in or register with a phone number and SMS verification code. Before the first task, check network, microphone, and speaker/headset availability, then grant contacts, phone, location, or camera permissions only when the selected feature requires them.

![Sign-in screen](images/login.png)

### 2. Home and task entry

The home screen presents phone-task entries, the selected call model, and primary navigation. Users can choose an enabled scenario or start a general task from the central voice entry.

![Home screen](images/home.png)

### 3. Describe a task by voice or text

After the task page completes its environment check, users can hold the voice button or switch to text input. The system interprets the task, asks for missing information, and requests confirmation before execution.

![Voice task](images/task-voice.png)

![Text task](images/task-text.png)

### 4. Calling and real-time translation

The dialer confirms the callee number, model, and translation setting. Supported tasks can be called by the hosted agent. Translation calls can display live transcripts and translated text for both parties.

![Dialer](images/dialer.png)

### 5. History and results

Completed calls appear in call history. Users can review time, number, transcript, task result, and recordings when access is authorized.

![Call history](images/call-history.png)

### 6. Settings and voices

Settings manage identity information, AI call models and voices, trusted-call options, app updates, and log upload. Voice-clone identity verification can be enabled when the required commercial services are separately licensed.

![Settings](images/settings.png)

![AI voice settings](images/voice-settings.png)

## Core capabilities

- Natural-language phone tasks through voice or text.
- Conversational task completion for required fields such as time, location, contact, and party size.
- Hosted orchestration of models, SIP, and business tools.
- Bidirectional transcript and translation presentation during supported calls.
- Authorized local contacts and number selection.
- Persisted task status, call history, transcripts, and receipts.
- Hosted model catalog with client-side voice preferences.
- User-initiated client log export or upload for troubleshooting.

## Technology overview

- Kotlin, Jetpack Compose, and AndroidX
- MVVM, unidirectional data flow, Kotlin Coroutines, and Flow
- Retrofit and OkHttp for HTTP and SSE
- WebSocket audio and real-time event transport
- Client SIP, WebRTC, audio capture, and playback
- Local caching, contacts, call log, and OTA integration

## Open-source boundary

This repository is intended for understanding, building, and extending the Android client. It does not include:

- Java/Spring backend or admin-console source;
- production credentials for models, SMS, SIP, maps, or object storage;
- production databases, operations scripts, deployment topology, or internal engineering records;
- commercial AAR/JAR files that cannot be publicly redistributed.

The client and hosted backend cooperate through HTTPS, SSE, WebSocket, and phone-media protocols. Developers may customize the UI, client policies, or connect an independently implemented compatible service, but the server implementation cannot be derived from this repository.

## Responsible use

Outbound calls, recordings, contacts, identity information, location, and voice cloning may be regulated by law, carriers, and service providers. Users must obtain required consent, avoid unnecessary sensitive data, and remain responsible for their numbers, content, charges, and compliance.
