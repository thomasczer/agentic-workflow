<!--
  Skeleton for one slice at most. Slice 00 makes "Run locally" real (replayed on a clean clone);
  every slice keeps the rest true. A section with nothing to say yet says "Nothing yet." —
  never a "to be written" that could ship.
  A current-state document, not a log: each slice rewrites what it changed and deletes what is no
  longer true (git keeps it). About 150 lines; a topic that needs more (a feature's walkthrough, an
  API, the architecture in depth) gets its own docs/<topic>.md and a one-line link here.
-->

# <Project name>

<!-- One or two sentences: what this is and what it does. -->

## Live demo

<!-- Deployed URL, or delete if run-locally only. -->

## Run locally

```bash
cp .env.example .env    # fill in the values (see below)
# install deps, start services, run migrations/seed, start the app
```

### Required environment variables

<!-- Keep in sync with .env.example. -->

| Var   | Purpose |
| ----- | ------- |
| `...` | `...`   |

## Architecture notes

<!-- 5–10 lines: the shape of the app, where data access / business logic lives, how mutations happen, how inputs are validated, how auth works. Why this shape. -->

## Data model & assumptions

<!-- The entities and the non-obvious decisions. State every assumption you made where the requirements were ambiguous, and why. -->

## Security notes

<!-- Authorization model, what is validated server-side, how untrusted input / amounts are handled, any tenant isolation. -->

## Testing

<!-- What is covered and how to run it. -->

## Known limitations / what was cut and why

<!-- Be explicit — this reads as scope control, not weakness. Current limitations only, one line each, linking to the doc of the topic: the slice that makes a cut adds its line, the slice that lifts it deletes it. -->

## What I would do next

<!-- Three to five lines, ordered; the first items are usually the evidence you do not have yet. The full list is the open issues. -->
