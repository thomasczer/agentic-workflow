---
description: Explore finds a definition and its callers, and cites each with path:line.
runs: 3
max_turns: 10
allowed_tools: [Read, Glob, Grep, Agent]
---

Dispatch the `agentic-workflow:Explore` agent (Agent tool) with this question: "Where is `applyDiscount` defined, and where is it called?" Do not search yourself. Then give its answer, keeping every `path:line` it cites.
