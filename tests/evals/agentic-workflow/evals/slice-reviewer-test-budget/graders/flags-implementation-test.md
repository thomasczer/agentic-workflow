---
type: llm
criteria: >-
  PASS if the report has a finding on the test "compares the total through pricing.atLeast" in test/shipping.test.js
  that says it asserts how the code is written (a helper called, a mock of this project's own module) rather than
  a behaviour of the plan, and whose fix is to delete or rewrite it. FAIL if that test is not reported, or is
  reported as fine.
---

The test that asserts the implementation is reported for deletion.
