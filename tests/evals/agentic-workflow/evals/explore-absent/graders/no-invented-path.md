---
type: regex
pattern: '(?:src|lib|app)/[\w/.-]*(?:webhook|signature|stripe|payment)'
match: not_contains
flags: i
---

No webhook or payment path that does not exist is cited.
