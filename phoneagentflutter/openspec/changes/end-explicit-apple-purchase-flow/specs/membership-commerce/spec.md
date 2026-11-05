## ADDED Requirements

### Requirement: Explicit Apple cancellation ends the server workflow
The client MUST report StoreKit userCancelled through the owner-scoped close command and retain the server order as the authority. It MUST NOT claim payment absence or release the slot only in memory. Pending or unknown outcomes MUST NOT invoke this end command automatically.

#### Scenario: Explicit cancellation response is received
- **WHEN** the native result is userCancelled and the server accepts local workflow cancellation
- **THEN** a fresh membership quote is possible without finishing any nonexistent transaction

#### Scenario: Historical processing original is restored
- **WHEN** the owner restores an unpaid Apple PROCESSING original
- **THEN** an explicit end action is available without blindly launching a second payment

#### Scenario: End request response is lost
- **WHEN** the close request fails or the server still returns an unresolved original
- **THEN** it remains recoverable and no replacement order is automatically created

#### Scenario: Already paid original
- **WHEN** the server returns a paid original
- **THEN** payment and fulfillment recovery win, and it cannot be locally canceled

### Requirement: Membership consent occurs once in the payment confirmation
The membership offer MUST NOT show an outer agreement checkbox. The mandatory membership payment confirmation MUST retain an initially unchecked agreement checkbox and prohibit confirmation until consent is given. Points pack agreement behavior MUST remain unchanged.

#### Scenario: User selects a membership
- **WHEN** the membership offer and payment confirmation are shown
- **THEN** only the confirmation contains the consent checkbox and payment remains disabled before consent
