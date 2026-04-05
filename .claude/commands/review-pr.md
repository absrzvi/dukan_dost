Run the full review gate for story: $ARGUMENTS

Steps (both must pass before raising the PR):

1. code-reviewer agent:
   - Review all changed files in the feature branches for story $ARGUMENTS
   - Output Critical / Warnings / Suggestions / Verdict
   - If CHANGES REQUIRED: return specific fixes to the developer (flutter-dev or django-dev as appropriate)
   - Loop until APPROVED

2. security-sentinel agent (runs after code-reviewer approves):
   - Scan all changed files for security issues — focus on cross-shop leakage, OTP handling, event log immutability
   - If BLOCKED: return exact fix required to the developer
   - Loop until APPROVED

3. devops agent (runs only after both above are APPROVED):
   - Raise a PR for both feature branches (flutter and django)
   - Populate PR description from docs/stories/$ARGUMENTS.md
   - Include: what was built, tests passing, offline scenario verified, rollback procedure
   - Output: PR URL

Output: "READY FOR HUMAN REVIEW — PR raised at [URL]. Please review and merge."
