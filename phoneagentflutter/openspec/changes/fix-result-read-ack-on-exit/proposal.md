# Proposal

When a conversation already renders a result card, leaving the conversation can race the
post-frame read acknowledgement and leave the task-list unread marker behind. The client
should flush the result acknowledgement during host disposal, while continuing to keep
physical-only hangup states unread. Result-state detection must include unsuccessful
business outcomes such as `INCOMPLETE` and `EXECUTION_ERROR`.

This is a Flutter-only lifecycle/read-ack repair. It does not change the task-list API,
database fields, call state machine, billing, or backend terminal-state calculation.
