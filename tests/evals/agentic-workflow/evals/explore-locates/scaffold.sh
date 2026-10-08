#!/usr/bin/env bash
# A small shop: applyDiscount is defined in src/cart.js:3 and called from two places; no webhook code.
set -euo pipefail
mkdir -p src/admin
printf '%s\n' '// Cart arithmetic.' '' 'export function applyDiscount(total, pct) {' '  return Math.round(total * (100 - pct)) / 100;' '}' > src/cart.js
printf '%s\n' "import { applyDiscount } from './cart.js';" '' 'export function checkout(cart) {' '  const total = cart.items.reduce((s, i) => s + i.price, 0);' '  return applyDiscount(total, cart.discountPct);' '}' > src/checkout.js
printf '%s\n' "import { applyDiscount } from '../cart.js';" '' '// Refunds re-apply the discount the order had.' '' 'export function refund(order) {' '  const paid = order.total;' '  return applyDiscount(paid, order.discountPct);' '}' > src/admin/refund.js
printf '%s\n' '# Shop' '' 'A toy shop used by the evals.' > README.md
