## ADDED Requirements

### Requirement: Original Apple transactions survive account lifecycle
The system SHALL reconcile only an existing Apple transaction using verified application identity and Apple evidence without requiring the original user's active login, and SHALL preserve its original ownership and financial processing.

#### Scenario: Original owner has been deleted
- **WHEN** a valid signed original transaction is submitted after account final deletion
- **THEN** the original financial workflow continues without resurrecting the account or disclosing its data to the current user

### Requirement: Finish requires authoritative fulfillment
The new client SHALL finish an Apple transaction only after the server confirms both payment and fulfillment succeeded, persisting retry evidence across account switches and restarts.

#### Scenario: Payment succeeded but fulfillment is pending
- **WHEN** the reconciliation result is not fully fulfilled
- **THEN** finishAllowed is false and the transaction remains available for bounded recovery

### Requirement: Material admission uses the verified authentication epoch
The system SHALL check account availability and the verified token epoch after acquiring the shared wallet lock before authorizing new payment material, without adding required fields to legacy requests or fencing settlement.

#### Scenario: Cancellation then revocation races an old request
- **WHEN** the account becomes ACTIVE again but its epoch changed before material authorization
- **THEN** the old request is rejected and original payment callbacks and fulfillment remain processable
