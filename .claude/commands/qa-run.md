Run the full 8-agent QA loop for: $ARGUMENTS

Deploy agents in this sequence:

1. Browser agent (tester with Playwright MCP):
   Navigate the live app/web view, capture accessibility tree and real DOM selectors for all screens related to $ARGUMENTS.

2. Analyst agent (tester):
   Map all testable surfaces. Include offline scenarios — connectivity loss during transaction entry.

3. Planner agent (tester):
   Prioritise: P0 (offline write, sync, auth), P1 (all workflows, WhatsApp reminder), P2 (edge cases, empty states, partial payments).

4. Engineer agent (tester):
   Write Flutter test / Playwright .spec.ts files using real selectors — never invent selectors.

5. Sentinel agent (code-reviewer):
   Audit generated tests for anti-patterns: fragile selectors, incorrect assertions, tests that can never fail.

6. Healer agent team (tester + tester):
   Run all tests. For each failure: diagnose if test is wrong or code is wrong. Fix the right one.

7. Expander agent (tester):
   Review for gaps. Add 3-5 new edge case tests — focus on offline/sync scenarios not yet covered.

8. Snapshot agent (tester):
   Create visual baselines at mobile 375px, tablet 768px, desktop 1440px.

SCORING: P0=40pts, P1=30pts, P2=15pts, Snapshots=15pts. Pass threshold: 85/100.
If score < 85 after all 8 steps: repeat from step 3. Maximum 3 full loops.
