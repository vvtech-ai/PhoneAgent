## ADDED Requirements

### Requirement: Unpublished catalog is a legitimate empty state
The App MUST treat the server's valid unpublished catalog as unconfigured, without a loading-failure or native payment-product dependency. It MUST preserve genuine transport, authentication and malformed-response errors, total points and the existing ledger entry.

#### Scenario: No published configuration
- **WHEN** catalog loading succeeds with version zero, empty products and benefits
- **THEN** the App shows the unconfigured state without fake prices, rights, payment controls or a loading failure

#### Scenario: Real service failure
- **WHEN** the catalog or membership request fails
- **THEN** the App preserves a failure and retry instead of declaring an unconfigured success

#### Scenario: Platform-specific original transaction recovery
- **WHEN** the membership page is shown on Android
- **THEN** it omits the bottom restore-purchase button and preserves original order handling through orders and invoices
- **WHEN** the membership page is shown on iOS with an unpublished catalog
- **THEN** Apple original transaction restoration remains reachable without enabling new sales

### Requirement: Empty orders omit table navigation
The App MUST remove the horizontal-swipe instruction and MUST hide table headers and scroll-arrow controls when there are no orders, while retaining nonempty order scrolling and original invoice actions.

#### Scenario: Empty successful order page
- **WHEN** a successful page contains no orders
- **THEN** only the normal empty state is shown without table headers or arrow controls

#### Scenario: Orders exist
- **WHEN** an order page contains records
- **THEN** horizontal scrolling, order details and the fixed invoice action remain usable without the removed instruction
