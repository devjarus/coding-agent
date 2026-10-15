# Orders API

Errors: `{"type": "error", "code": "<code>", "message": "<text>"}`.

| Code | Status | Meaning |
|---|---|---|
| `invalid_request` | 400 | body missing or malformed |
| `order_not_found` | 404 | no order with that id |
| `order_not_payable` | 409 | only pending orders can be paid |

## `POST /orders`
Body `{"customer", "items": [{"sku", "qty", "price_cents"}]}` → `201` order.

## `GET /orders`
→ `200 {"orders": [...]}` ordered by id.

## `GET /orders/{id}`
→ `200` order: `{"id", "customer", "status", "total_cents", "created_at", "paid_at"}`.

## `POST /orders/{id}/pay`
Pending → `paid`, sets `paid_at`. → `200` order.
