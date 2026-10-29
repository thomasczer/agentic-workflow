---
type: llm
criteria: >-
  PASS if the report has a finding on the test "a total of exactly 50 is free" in test/shipping.test.js that says it
  repeats or duplicates "50 is free" (or adds nothing to it) and whose fix is to delete it. FAIL if that test is not
  reported, or is reported as fine.
---

The duplicate test is reported for deletion.
