Run Playwright UI tests for the Phase 2 customer web view: $ARGUMENTS

Steps:
1. Use the tester agent (which has Playwright MCP access)
2. Navigate to the running web view (default: http://localhost:3000)
3. Browse the feature — capture real DOM selectors using browser_snapshot
4. Generate Playwright tests in e2e/$ARGUMENTS.spec.ts using actual selectors
5. Run: npx playwright test $ARGUMENTS.spec.ts
6. If failing: navigate to current app state, diagnose, fix, re-run
7. Repeat until all tests pass
8. Take visual snapshots at mobile 375px (primary), tablet 768px, desktop 1440px
9. Report: pass/fail count, selectors used, viewport coverage
