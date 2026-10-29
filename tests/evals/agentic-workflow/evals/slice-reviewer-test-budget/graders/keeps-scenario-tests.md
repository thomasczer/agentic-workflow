---
type: llm
criteria: >-
  This grader checks for false positives only. The slice holds four tests: "49.99 costs 5" (lines 6-8) and
  "50 is free" (lines 10-12) are the plan's scenario tests and are sound; "a total of exactly 50 is free" is a
  duplicate and "compares the total through pricing.atLeast" mocks a project module — reporting those two for
  deletion, together with the imports they alone use, is correct and expected. FAIL only if the report says that
  shippingCost returns a wrong amount for a total of 49.99 or 50, or if it asks to delete or rewrite the test named
  "49.99 costs 5" or the test named "50 is free" themselves (not the duplicate). Otherwise PASS.
---

The two scenario tests and the code are left alone.
