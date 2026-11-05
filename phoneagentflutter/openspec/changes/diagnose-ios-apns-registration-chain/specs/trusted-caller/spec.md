## ADDED Requirements
### Requirement: iOS APNs registration chain observability
The client SHALL distinguish permission, configuration gate, registration invocation, system callback, token validation, SDK bootstrap and binding results using bounded safe diagnostic codes. Diagnostics SHALL NOT alter registration, binding, retry or account isolation behavior.

#### Scenario: No APNs callback observed
- **WHEN** registration has been invoked and no success or failure callback arrives within twenty seconds
- **THEN** one pending observation is emitted for that wait generation without claiming failure or retrying registration

#### Scenario: Token callback validation
- **WHEN** a system token callback arrives
- **THEN** callback receipt and existing validation outcome are distinguishable without recording the token

#### Scenario: Export registration chain
- **WHEN** native registration and SDK stage events reach Flutter
- **THEN** diagnostic export and restoration retain the fixed codes and reject private arbitrary metadata
