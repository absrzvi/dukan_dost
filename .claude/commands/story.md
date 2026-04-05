Write story files for: $ARGUMENTS

Pre-conditions (check both — stop if either fails):
- docs/PRD.md must have Status: APPROVED
- docs/ARCHITECTURE.md must have Status: APPROVED

Steps:
1. Use the scrum-master agent
2. Read docs/PRD.md, docs/ARCHITECTURE.md, docs/API_CONTRACTS.md, docs/DATA_MODEL.md
3. Write one story file per logical unit of work to docs/stories/STORY-XXX-[slug].md
4. Use the next available story number (check existing files in docs/stories/)
5. Each story must include the offline behaviour section — no exceptions
6. Output: list of story files created with a one-line summary of each
