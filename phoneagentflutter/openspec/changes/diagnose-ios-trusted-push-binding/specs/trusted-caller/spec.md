## ADDED Requirements
### Requirement: Observe current iOS push binding acknowledgement
The Flutter iOS bridge SHALL report bounded current binding diagnostics when its current consumer subscribes or notification authorization is refreshed, without invoking SDK operations for observation.

#### Scenario: Acknowledged current binding
- **WHEN** the exact desired account, login epoch, environment and Token have a successful binding callback and no cleanup is required
- **THEN** the snapshot reports IOS_BIND_STATE_CONFIRMED with received result, without exposing identity or Token

#### Scenario: Pending or uncertain request
- **WHEN** initialization or binding is pending, failed, or belongs to an old account
- **THEN** diagnostics distinguish those states and do not report current binding confirmation or automatically retry

#### Scenario: Stale consumer
- **WHEN** a previous consumer requests a snapshot
- **THEN** no diagnostic is emitted
