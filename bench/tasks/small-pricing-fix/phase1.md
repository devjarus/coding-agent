Customers are reporting wrong checkout totals from `pricing.py`. Please fix it:

1. Buying **exactly 10** units of an item doesn't get the 10% bulk discount. It should (10 or more).
2. Using `SAVE5` on a small order (e.g. $3.00) produced a **negative** total. The coupon can reduce the subtotal to $0.00 but never below.
3. Totals that land on half a cent round the wrong way. Accounting wants **round half up** to cents (e.g. 10.125 → 10.13).

Also add one feature:

4. A new coupon `PCT10`: 10% off the subtotal (after bulk discounts, before tax).
   Only one coupon per order — the `coupon` argument stays a single code.
   An unknown coupon code must raise `ValueError`. `None` still means no coupon.

Keep the public functions `line_total(unit_price, qty)` and `order_total(lines, coupon=None)` and their return type (`Decimal`). Add tests for the fixes.
