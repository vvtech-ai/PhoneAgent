## ADDED Requirements

### Requirement: Observe an owned single-recipient batch without changing execution
The system SHALL reuse the realtime call surface only for a confirmed batch whose frozen executable recipient count is exactly one, for every batch Skill. Confirmation, execution, entitlement, billing, retries and batch outcomes SHALL retain their current owners.

#### Scenario: One executable recipient
- **WHEN** the owned admission contains exactly one executable recipient
- **THEN** its current attempt may be observed without another confirmation or dialing command

#### Scenario: Sequential or partially completed multiple recipients
- **WHEN** admission contains multiple recipients even if concurrency is one or only one route remains active
- **THEN** the existing batch presentation remains

### Requirement: Preserve call readiness and identity gates
The system SHALL show the realtime surface only with explicit SDK launchReady true for the owned current attempt and no terminal, ending or primary closure proof.

#### Scenario: Preparation not proven
- **WHEN** only confirmation, tool start, callId or missing/false readiness is available
- **THEN** the realtime page does not open and no START is issued by observation

#### Scenario: Reconnect and retry
- **WHEN** current progress is restored or a newer retry starts
- **THEN** reads bind to the original account/session/batch and current attempt; stale responses cannot reopen an old call

#### Scenario: Repeated confirmed single-recipient execution
- **WHEN** a batch has finished and the current conversation accepts a new execution command and a new single-recipient batch, without a tool-start event
- **THEN** the new attempt is observed and uses the existing realtime page only after its own SDK readiness passes, for every Skill and every subsequent execution
- **AND** completed batches, stale commands, repeated tool-start events and late status responses cannot replace the current observation or clear its stop/closure gate

#### Scenario: Multiple recipients after a finished call
- **WHEN** the next execution contains multiple frozen recipients or merely has one remaining route
- **THEN** it retains existing batch presentation and cannot become a single-recipient call through a later partial progress update

### Requirement: Stop the original execution
The system SHALL route explicit hangup through existing batch stop, including pending retries, and leave batch result settlement unchanged.

#### Scenario: User hangs up
- **WHEN** the user hangs up the observed single-recipient batch
- **THEN** existing stopBatch is requested and the system waits for physical closure instead of fabricating a final result
