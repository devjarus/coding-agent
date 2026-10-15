# Orders API

Errors: `{"type": "error", "code": "<code>", "message": "<text>"}`.

| Code | Status | Meaning |
|---|---|---|
| `invalid_request` | 400 | body missing or malformed |
| `order_not_found` | 404 | no order with that id |
| `order_not_payable` | 409 | only pending orders can be paid |
| `order_not_cancellable` | 409 | only pending orders can be cancelled |

## `POST /orders`
Body `{"customer", "items": [{"sku", "qty", "price_cents"}]}` → `201` order.

## `GET /orders`
→ `200 {"orders": [...]}` ordered by id. Cancelled orders are omitted unless `?include_cancelled=true`.

## `GET /orders/{id}`
→ `200` order: `{"id", "customer", "status", "total_cents", "created_at", "paid_at"}`.

## `POST /orders/{id}/pay`
Pending → `paid`, sets `paid_at`. → `200` order.

## `POST /orders/{id}/cancel`
Body `{"reason"}` (required). Pending → `cancelled`, sets `cancelled_at` and `cancel_reason`. → `200` order.
