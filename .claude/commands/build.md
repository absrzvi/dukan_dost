Implement story: $ARGUMENTS

Pre-condition: docs/stories/$ARGUMENTS.md must have Status: READY

Create an agent team with two teammates:

Teammate 1 — flutter-dev:
- Read docs/stories/$ARGUMENTS.md (Flutter Screen Spec section)
- Work in git worktree: feature/$ARGUMENTS-flutter
- TDD loop: write failing test → implement → run → fix (max 5 attempts) → BLOCKED if still failing
- Message django-dev immediately if any API contract in docs/API_CONTRACTS.md needs to change

Teammate 2 — django-dev:
- Read docs/stories/$ARGUMENTS.md (Django Endpoint Spec section)
- Work in git worktree: feature/$ARGUMENTS-django
- TDD loop: write failing test → implement → run → fix (max 5 attempts) → BLOCKED if still failing
- Message flutter-dev immediately if any response schema changes

Both teammates require plan approval before writing any code.
If either teammate sets story Status to BLOCKED, invoke the debugger agent with the full error context.
