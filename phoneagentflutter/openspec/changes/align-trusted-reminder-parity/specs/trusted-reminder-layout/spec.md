## ADDED Requirements

### Requirement: Reminder matches the native reference without disturbing lifecycle
The reminder SHALL use a compact 280 logical pixel surface with no title placeholder, 20 pixel padding, dark 14 pixel body text and a 52 pixel gradient confirmation button. Small screens and enlarged text MUST remain usable. Existing account, back and platform lifecycle SHALL remain unchanged.

#### Scenario: Dismiss initial guide
- **WHEN** the initial guide is dismissed on Android
- **THEN** a compact readable reminder is shown and its single confirmation closes it

#### Scenario: Small screen with enlarged text
- **WHEN** available height or width is constrained
- **THEN** the content remains reachable without overflow
