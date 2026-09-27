Next slice for the inventory service in this repo: warehouses and stock.

- `POST /warehouses` `{"code", "name"}` → `201` `{"code", "name", "created_at"}`. `code` is 2–10 uppercase letters or digits. Duplicate code is a conflict.
- `GET /warehouses` → list, ordered by code.
- `PUT /items/{sku}/stock/{code}` `{"qty"}` sets that item's quantity in that warehouse (non-negative integer) → `200` `{"sku", "warehouse", "qty"}`. Unknown item or warehouse → not found.
- `GET /items/{sku}` now also includes `"stock": {"<code>": qty, ...}` and `"total_qty"` (sum across warehouses).

Follow the API conventions we agreed on.

One more thing for later, not now: we'll want **low-stock alerts** — each item gets an optional `low_stock_threshold` (set via `PATCH /items/{sku}`), and `GET /alerts/low-stock` lists items whose `total_qty` is below their threshold, each as `{"sku", "name", "total_qty", "low_stock_threshold"}`, ordered by sku. Don't build it yet, but make sure it doesn't get lost.
