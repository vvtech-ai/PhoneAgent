# Privacy and Permissions

Permissions should be requested only when the selected feature needs them:

| Permission group | Typical purpose | If denied |
| --- | --- | --- |
| Microphone and audio | Voice tasks, calls, translation | Voice input and related calls are unavailable |
| Camera | Authorized identity verification | Voice-clone verification is unavailable |
| Contacts | Contact selection | Numbers can still be entered manually |
| Phone and phone numbers | Dialing, SIM, trusted-call assistance | Related phone features are limited |
| Call log | Device call history | Only backend history, or no device history, is shown |
| Location | Location-aware tasks and map search | Location must be described manually |
| Overlay | Optional call controls | Floating controls are unavailable |
| Package install | User-confirmed OTA install | Updates must be installed manually |

Do not provide unrelated identity numbers, payment data, passwords, verification codes, health data, or other sensitive information in tasks, calls, or logs. Log upload must be user initiated, and logs must be redacted before publication or inclusion in an issue.

Outbound calls, recordings, translation, identity verification, and voice cloning must follow applicable law, carrier rules, and vendor terms, including explicit participant consent where required.
