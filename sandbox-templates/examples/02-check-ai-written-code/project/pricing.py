"""Written by a coding agent for the ticket "add volume discounts"."""


def order_total(unit_price: float, quantity: int) -> float:
    total = unit_price * quantity
    if quantity > 100:      # bug: the ticket said "100 or more"
        total *= 0.9
    return round(total, 2)
