## ADDED Requirements
### Requirement: Current native developer tools parity
The unlocked Flutter developer tools page SHALL mirror the current aiassistant_app formal sections and actions, including server-directory caller-country simulation and account translation model debugging.

#### Scenario: Choose a simulated caller country
- **WHEN** the developer selects a directory country
- **THEN** the app SHALL persist the override separately from real location and use it for country-bound model/node selection, account settings region, and translation location permission gating
- **AND** SHALL leave the called country, language and dial model selection unchanged

#### Scenario: Restore automatic location
- **WHEN** the developer disables simulation or selects automatic location
- **THEN** the app SHALL clear the override, restore trusted location and refresh location without overwriting real location with simulated data

#### Scenario: Account model debug preference
- **WHEN** the developer opens account translation models and selects an available account preference
- **THEN** the app SHALL load/update settings for the effective caller region
- **AND** SHALL preserve the independently selected dial model ID

#### Scenario: Formal page actions
- **WHEN** the unlocked formal page is opened
- **THEN** it SHALL show list data, outbound debugging, realtime translation and V8.8 simulation in native order
- **AND** SHALL omit legacy forced WebRTC, fixed node/model choices and migration MOCK routes
- **AND** permission reset SHALL reset app prompt state and open the translation dialer, without revoking OS permissions
