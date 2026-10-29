#!/usr/bin/env bash
# A slice whose code is right and whose two scenario tests are sound, plus two tests the plan did not ask for:
# a duplicate of "50 is free", and one that spies on the comparison helper (how the code is written).
set -euo pipefail
g() { git -c user.name=eval -c user.email=eval@example.com "$@"; }
git init -q -b main
mkdir -p src test docs/plans
printf '%s\n' '# Shop' '' 'Run the tests with `node --test`.' > README.md
cat > CLAUDE.md <<'MD'
# Shop

- Tests: `node --test`.

## Testing

- The tests of a task are the scenarios its plan assigns to it, at the level the plan says. A test that duplicates another, or that asserts how the code is written rather than what it does, is deleted in the slice that meets it.
- Mock only at a process boundary (the network, the clock, the filesystem, an external program), never a module of this project.
MD
printf '%s\n' '// Amount comparisons.' '' 'export const pricing = {' '  atLeast(amount, bar) {' '    return amount >= bar;' '  },' '};' > src/pricing.js
g add -A && g commit -qm 'chore: baseline'
git switch -qc feat/01-shipping
cat > docs/plans/01-shipping.md <<'PLAN'
# 01 — Shipping cost

Loop: light

## Acceptance criteria

1. `shippingCost(total)` returns 0 when the cart total is 50 or more.
2. `shippingCost(total)` returns 5 below 50.

## Tasks

1. Add `shippingCost` in `src/shipping.js`.

## Tests, by task

- Task 1, unit: 49.99 costs 5.
- Task 1, unit: 50 is free.

## Out of scope

Shipping zones, weight.
PLAN
printf '%s\n' '// Flat shipping, free from FREE_FROM.' "import { pricing } from './pricing.js';" '' 'export const FREE_FROM = 50;' '' 'export function shippingCost(total) {' '  return pricing.atLeast(total, FREE_FROM) ? 0 : 5;' '}' > src/shipping.js
cat > test/shipping.test.js <<'JS'
import { test, mock } from 'node:test';
import assert from 'node:assert/strict';
import { pricing } from '../src/pricing.js';
import { shippingCost } from '../src/shipping.js';

test('49.99 costs 5', () => {
  assert.equal(shippingCost(49.99), 5);
});

test('50 is free', () => {
  assert.equal(shippingCost(50), 0);
});

test('a total of exactly 50 is free', () => {
  assert.equal(shippingCost(50), 0);
});

test('compares the total through pricing.atLeast', () => {
  const atLeast = mock.method(pricing, 'atLeast');
  shippingCost(49.99);
  assert.equal(atLeast.mock.callCount(), 1);
  assert.deepEqual(atLeast.mock.calls[0].arguments, [49.99, 50]);
  atLeast.mock.restore();
});
JS
g add -A && g commit -qm 'feat(shipping): flat shipping cost'
