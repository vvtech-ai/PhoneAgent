# Design

`VisibleTaskResultRead` remains the single owner of visible result acknowledgements.
Receipt classification reuses `CallReceiptStatus.outcome` and adds the explicit
business-result statuses that render an unsuccessful result card. Physical-only states
such as `ENDED` and bare `CALL_COMPLETED` remain excluded.

The read owner tracks the active acknowledgement future. On host disposal it captures the
currently supplied messages, waits for an acknowledgement already in flight, or performs
one final acknowledgement for a result card that was rendered but had not yet reached its
post-frame callback. The route callback remains account-epoch guarded but is allowed to
finish this final acknowledgement after the controller begins closing.

No server contract or database parameter changes are required.
