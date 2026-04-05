Fix bug: $ARGUMENTS

Steps (in this exact order — do not skip the regression test step):
1. tester agent: write a failing Flutter test or pytest test that reproduces the bug exactly. Do not proceed until this test fails for the right reason.
2. debugger agent: read the failing test, identify root cause, implement the minimal fix.
3. Run the regression test — it must now pass.
4. Run the full test suite — no new failures allowed.
5. Verify offline scenario if the bug touched any sync or write path.
6. security-sentinel agent: verify the fix does not introduce any security issues.
7. Output: root cause summary, files changed, regression test location

The regression test stays in the test suite permanently.
