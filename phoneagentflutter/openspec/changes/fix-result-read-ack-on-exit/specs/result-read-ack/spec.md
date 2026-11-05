## ADDED Requirements

### Requirement: Visible result cards are acknowledged before leaving
The conversation result-read owner MUST acknowledge a rendered business result when the
conversation host is disposed, including unsuccessful result states such as `INCOMPLETE`
and `EXECUTION_ERROR`.

#### Scenario: User exits immediately after an incomplete result appears
- **GIVEN** an `INCOMPLETE` result card is rendered for the current account
- **WHEN** the conversation route is removed before the scheduled acknowledgement finishes
- **THEN** exactly one idempotent task read acknowledgement is attempted

#### Scenario: Physical hangup has no business result
- **GIVEN** only `ENDED` or bare `CALL_COMPLETED` receipts are present
- **WHEN** the conversation route is removed
- **THEN** no result acknowledgement is attempted

### Requirement: Hidden or stale results remain unread
The result-read owner MUST NOT acknowledge results that arrive while the route is covered,
the owner is stale, or the login epoch has changed.

#### Scenario: Result arrives after the route is covered
- **GIVEN** the conversation route is not current
- **WHEN** a result receipt arrives
- **THEN** it remains eligible for a later visible acknowledgement and is not acknowledged while hidden
