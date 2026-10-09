---
type: llm
criteria: >-
  PASS if the report says that the tests in test/shipping.test.js do not really check the amounts the plan
  requires (5 below 50, 0 from 50) — for example that a wrong implementation, or one returning undefined,
  would still pass them. FAIL if the report treats those tests as adequate coverage of the plan.
---

The vacuous tests are reported as tests that cannot fail.
