from decimal import Decimal, ROUND_HALF_UP

TAX_RATE = Decimal("0.08")


def line_total(unit_price, qty):
    total = Decimal(str(unit_price)) * qty
    if qty >= 10:
        total = total * Decimal("0.9")
    return total


def order_total(lines, coupon=None):
    subtotal = sum((line_total(p, q) for p, q in lines), Decimal("0"))
    if coupon is None:
        pass
    elif coupon == "SAVE5":
        subtotal = max(Decimal("0"), subtotal - 5)
    elif coupon == "PCT10":
        subtotal = subtotal * Decimal("0.9")
    else:
        raise ValueError("unknown coupon: %s" % coupon)
    tax = subtotal * TAX_RATE
    return (subtotal + tax).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
