Begin architecture phase for the feature described in docs/PRD.md.

Pre-condition: docs/PRD.md must have Status: APPROVED — check this first. If not approved, stop and tell the user.

Steps:
1. Use the architect agent
2. Read docs/PRD.md
3. Write ADR to docs/ARCHITECTURE.md with Status: AWAITING SIGN-OFF
4. Update docs/DATA_MODEL.md with new Drift table definitions or Django models
5. Update docs/API_CONTRACTS.md with new endpoint specs
6. Create/update wireframes/INDEX.html with HTML prototype (chat-thread layout, large keypad, Urdu labels)
7. Output: "ARCHITECTURE COMPLETE — please review docs/ARCHITECTURE.md, set Status to APPROVED when happy"
