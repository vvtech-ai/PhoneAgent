## ADDED Requirements
### Requirement: Direct readable diagnostics are confined to Android Debug
The application SHALL allow direct reading of sanitized app-private diagnostic files only in Android Debug builds. Release and Profile SHALL retain encrypted diagnostic storage and SHALL NOT enable debuggable for log access.

#### Scenario: Debug files are readable through an authorized ADB shell
- **WHEN** Android Debug records and flushes a diagnostic event
- **THEN** a scoped app-private readable-debug mirror contains readable JSON index and JSONL events while the canonical archive remains encrypted with the same account scope and retention limits

#### Scenario: Existing encrypted debug files survive an upgrade
- **WHEN** Debug opens an existing encrypted diagnostic archive with its valid key
- **THEN** existing events remain readable through the application and new appends preserve sequence and acknowledgement semantics

#### Scenario: Release and other platforms retain encryption
- **WHEN** Release, Profile, or a non-Android platform records diagnostics
- **THEN** the file factory retains authenticated encryption and no runtime flag enables direct plaintext access

#### Scenario: Debug mirror cleanup recovers and survives build mode changes
- **WHEN** mirror deletion fails once or Android switches to protected storage and acknowledges uploaded events
- **THEN** subsequent transactions retry orphan cleanup, protected mode removes historical readable files without creating new plaintext, and the encrypted canonical journal remains usable
