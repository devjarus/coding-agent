The booking engine in this repo needs pricing, refunds and bigger groups. Keep every existing call working as before (existing `create_event(event_id, name, capacity)` calls and existing databases must keep working).

1. **Prices.** `create_event` gains optional keyword args `price_cents=0`, `tiers=None`, `starts_at=None`. `tiers` is a list of `(seats, price_cents)` early-bird bands applied in order to *confirmed* seats: e.g. `price_cents=1000, tiers=[(10, 500), (5, 800)]` means confirmed seats 1–10 cost 500, seats 11–15 cost 800, and every seat after that costs 1000.
2. **Quotes.** `bs.quote(event_id, seats)` → total cents to buy `seats` right now, given how many seats are currently confirmed (a purchase can span a band boundary).
3. **Bookings record what was paid.** `confirm` charges the quote at the moment of confirmation. `bs.booking(booking_id)` → `{"booking_id", "event_id", "customer", "seats", "price_cents", "status", "refund_cents"}` where `status` is `"confirmed"` or `"cancelled"` and `refund_cents` is `0` until cancelled.
4. **Refunds.** `cancel` now returns `refund_cents`: 100% of the price paid if cancelled at least 7 days before `starts_at`, 50% (rounded down to whole cents) if at least 24 hours before, otherwise 0. Events without `starts_at` always refund 100%. Cancelling twice returns `0` the second time. Cancelled seats go back on sale (and count toward early-bird bands again).
5. **Bigger groups.** A hold may now be for 1–8 seats.

Update the tests.
