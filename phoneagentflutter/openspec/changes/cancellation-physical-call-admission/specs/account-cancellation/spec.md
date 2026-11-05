## ADDED Requirements

### Requirement: Call-specific cancellation feedback
The client SHALL keep the existing shared UI and confirmation flow and SHALL display separate safe messages for an ongoing physical call and unavailable closure evidence.

#### Scenario: A physical call blocks submission
- **WHEN** SDK returns the recognized physical-call rejection
- **THEN** the client displays the call-specific message without mentioning tasks or payments

#### Scenario: Closure evidence is temporarily unavailable
- **WHEN** SDK cannot verify the end of a potentially delivered call
- **THEN** the client displays a retryable call-state message and does not claim cancellation was accepted
