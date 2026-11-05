## ADDED Requirements

### Requirement: Natural replies use contextual semantic classification

The client SHALL send every natural-language reply to a currently visible call confirmation through the configured semantic repository and SHALL NOT authorize dialing based on fixed phrases or suffixes.

#### Scenario: Affirmation awaits semantic result
- **WHEN** the user says “确认拨打” or “确定” against a visible pending card
- **THEN** dialing preparation starts only after the current semantic result is CONFIRM
- **AND** the original admission and preparation workflow is reused exactly once

#### Scenario: Negative suffix cannot authorize
- **WHEN** a reply ends with dialing words but means refusal or a question
- **THEN** the client waits for semantic classification and does not authorize from the suffix

### Requirement: Non-terminal replies preserve the current card

The client SHALL preserve the current pending card for QUESTION, WAIT, UNCLEAR and classification failure, recording existing supplemental dialogue without executing or regenerating a card.

#### Scenario: Question followed by confirmation
- **WHEN** a question is answered and the user later explicitly confirms the same card
- **THEN** the same tool identity is used and execution occurs once

#### Scenario: Obsolete semantic response
- **WHEN** account, session, card content or generation changes during classification
- **THEN** the obsolete result cannot authorize or change the new card
