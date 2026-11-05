## ADDED Requirements
### Requirement: Batch retry keeps confirmed workflow
The system SHALL retain the batch_plus confirmation workflow when retrying one selected recipient and SHALL NOT execute an ordinary makeCall for that workflow.
#### Scenario: One failed recipient is retried
- **WHEN** the user requests another attempt for one recipient of a batch task
- **THEN** a new batch confirmation is required for only the selected recipient, preserving recipient identity and task context before existing execution gates
### Requirement: Confirmation availability is distinct from intent
The system SHALL interpret the full reply to the current valid confirmation question and SHALL distinguish unavailable classification from a valid unclear decision.
#### Scenario: A service response is malformed
- **WHEN** classification fails because of service or parsing errors
- **THEN** at most one classification retry is permitted and continued failure cannot authorize dialing
#### Scenario: Affirmative reply contains a delay
- **WHEN** the user says “是的，但先别打”
- **THEN** the current card remains pending and dialing does not start
