Customers need to be able to cancel orders. Add `POST /orders/{id}/cancel` with a JSON body `{"reason": "..."}`:

- Only a `pending` order can be cancelled; anything else is a conflict (`409`, code `order_not_cancellable`).
- A reason is required (`400` if missing or empty).
- A cancelled order has status `cancelled` and records when it was cancelled and why (`cancelled_at`, `cancel_reason` on the order).
- `GET /orders` stops listing cancelled orders unless called with `?include_cancelled=true`.
