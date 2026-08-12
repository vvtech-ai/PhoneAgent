# Call Skill Vision

English | [简体中文](CALL_SKILLS.zh-CN.md)

> This document describes the public direction of Phone Agent. The Call Skill SDK, runtime, and distribution platform have not been released; all directories and interfaces below are conceptual examples.

## Why Call Skills

Phone workflows share a common backbone: understand the goal, collect required information, confirm risk, make the call, record the process, and return a result. Restaurant reservations, service appointments, after-sales calls, and meeting notifications nevertheless require different fields, dialogue rules, tools, and completion criteria.

Call Skills aim to package those differences as reusable, testable, and reviewable units, so developers can focus on the scenario instead of rebuilding the communication stack.

## Conceptual model

A Call Skill is expected to describe:

| Component | Purpose |
| --- | --- |
| Identity and version | Skill name, developer, version, and compatibility |
| Matching rules | User intents and scenarios the Skill recognizes |
| Input schema | Number, time, location, party size, and other required fields |
| Confirmation rules | Fields or actions that require explicit user approval |
| Dialogue policy | Call objective, wording constraints, clarification, and failure handling |
| Tool declarations | Map, calendar, order, or enterprise services the Skill may access |
| Completion criteria | Success, partial completion, failure, or human handoff |
| Result schema | Structured receipt returned to the client |
| Permissions and compliance | Contacts, location, recording, regions, and retention |
| Test fixtures | Happy path, rejection, no answer, conflicting information, and more |

## Envisioned lifecycle

```text
Discover user intent
  → match candidate Skills
  → check capability, version, and permissions
  → collect input slots
  → present and confirm the task
  → create a constrained call session
  → handle dialogue, tool events, and failures
  → validate completion criteria
  → return a structured result and audit trail
```

## Conceptual directory

This structure is for discussion only and is not a final specification:

```text
restaurant-booking/
  skill.yaml
  README.md
  prompts/
  policies/
  result-schema.json
  tests/
```

A future specification should support version validation, least privilege, deterministic inputs and outputs, redacted logs, simulation tests, and hosted-service capability negotiation.

## What developers could build

- Restaurant, hotel, and service appointments
- Meeting invitations and attendance confirmation
- After-sales, repair, and support coordination
- Delivery and on-site scheduling
- Flight, hotel, and rental-car confirmation
- Cross-language calls and accessibility assistance
- Enterprise notifications and structured follow-ups
- Authorized vertical-industry workflows

Actual operation will still depend on telephony, models, regions, business APIs, and compliance authorization.

## Safety baseline

Call Skill design must prioritize user control and communication safety:

- show the target, recipient, and key content before a real call;
- apply least privilege to numbers, contacts, recordings, and location;
- require limits and additional confirmation for bulk, concurrent, or high-frequency calls;
- handle rejection, no answer, identity questions, and human handoff;
- prohibit harassment, spam marketing, deception, and unauthorized impersonation;
- redact logs and results by default and follow retention policy;
- comply with applicable law, carrier rules, and provider terms.

## Path to openness

1. Publish the conceptual model, use cases, and Skill proposal process.
2. Design manifest, input-slot, result, and permission specifications.
3. Release example Skills, validators, and simulation tests.
4. Open a developer SDK and controlled local debugging workflow.
5. Explore a community catalog and distribution after safety and compatibility mature.

This is directional and does not promise dates. Use the [contribution guide](../CONTRIBUTING.md) to propose a Call Skill scenario, risk analysis, and test cases.
