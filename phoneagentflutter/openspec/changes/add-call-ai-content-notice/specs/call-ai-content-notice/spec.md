## ADDED Requirements

### Requirement: Call AI content notice
The client SHALL display “内容由AI生成” below the hangup label on both realtime translation and task call controls. It SHALL use the reference image’s neutral gray (#999999), regular-weight system font, retain the corresponding hangup label horizontal text alignment setting, and use font size equal to 0.7 times the original label size rounded to the nearest integer. Its vertical gap SHALL equal the existing button-to-label gap, while preserving control actions and states.

#### Scenario: Existing page styles
- **WHEN** either call control area is rendered
- **THEN** it shows exactly one notice using the shared neutral gray regular system font and that page's hangup label alignment, with notice font size 9sp for realtime translation and 8sp for task calls, separated by 7dp for realtime translation or 8dp for task calls
- **AND** existing button callbacks and disabled states remain unchanged

### Requirement: Complete notice content
The notice SHALL have sufficient width outside fixed button columns, preserve the specified rounded notice font size, and allow wrapping without truncation.

#### Scenario: Narrow layout and large text
- **WHEN** available width is narrow or system text scaling is increased
- **THEN** the complete notice remains visible with natural wrapping and no ellipsis, clipping, or font shrinking
