<!--
  Skeleton for one slice at most. Slice 00 makes "Run locally" real (replayed on a clean clone);
  every slice keeps the rest true. A section with nothing to say yet says "Nothing yet." —
  never a "to be written" that could ship.
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

<!-- Be explicit — this reads as scope control, not weakness. Updated by the slice that makes the cut, not at the end. -->

## What I would do next

<!-- Ordered. The first items are usually the evidence you do not have yet. -->
