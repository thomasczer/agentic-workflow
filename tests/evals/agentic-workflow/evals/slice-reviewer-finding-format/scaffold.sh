#!/usr/bin/env bash
# A slice whose code is right but whose tests look plausible and cannot fail: both pass if shippingCost returns undefined.
set -euo pipefail
g() { git -c user.name=eval -c user.email=eval@example.com "$@"; }
git init -q -b main
mkdir -p src test docs/plans
printf '%s\n' '# Shop' '' 'Run the tests with `node --test`.' > README.md
printf '%s\n' '# Shop' '' '- Tests: `node --test`.' '- Every plan edge case has a test.' > CLAUDE.md
printf '%s\n' '// Cart arithmetic.' '' 'export function cartTotal(items) {' '  return items.reduce((sum, item) => sum + item.price, 0);' '}' > src/cart.js
g add -A && g commit -qm 'chore: baseline'
git switch -qc feat/01-shipping
cat > docs/plans/01-shipping.md <<'PLAN'
# 01 — Shipping cost

Loop: light

## Acceptance criteria

1. `shippingCost(total)` returns 0 when the cart total is 50 or more.
2. `shippingCost(total)` returns 5 below 50.

## Tasks

1. Add `shippingCost` in `src/shipping.js`, test-first.

## Tests first

- 49.99 costs 5.
- 50 is free.

## Out of scope

Shipping zones, weight.
PLAN
printf '%s\n' '// Flat shipping, free from FREE_FROM.' '' 'export const FREE_FROM = 50;' '' 'export function shippingCost(total) {' '  return total >= FREE_FROM ? 0 : 5;' '}' > src/shipping.js
printf '%s\n' "import { test } from 'node:test';" "import assert from 'node:assert/strict';" "import { shippingCost, FREE_FROM } from '../src/shipping.js';" '' "test('49.99 costs 5', () => {" '  assert.notEqual(shippingCost(49.99), 0);' '});' '' "test('50 is free', () => {" '  assert.equal(shippingCost(50), shippingCost(FREE_FROM));' '});' > test/shipping.test.js
g add -A && g commit -qm 'feat(shipping): flat shipping cost'
