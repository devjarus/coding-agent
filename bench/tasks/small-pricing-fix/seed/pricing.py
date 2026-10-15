"""Order pricing for the shop."""
from decimal import Decimal

TAX_RATE = Decimal("0.08")


def line_total(unit_price, qty):
    """Price for qty units. Bulk discount: 10% off a line when qty is 10 or more."""
    total = Decimal(str(unit_price)) * qty
    if qty > 10:
        total = total * Decimal("0.9")
    return total


def order_total(lines, coupon=None):
    """Total for an order.

    lines: list of (unit_price, qty) tuples.
    coupon: optional code. "SAVE5" takes $5 off the subtotal.
    Tax is applied after the coupon. Result is rounded to cents.
    """
    subtotal = sum((line_total(p, q) for p, q in lines), Decimal("0"))
    if coupon == "SAVE5":
        subtotal -= 5
    tax = subtotal * TAX_RATE
    return (subtotal + tax).quantize(Decimal("0.01"))
