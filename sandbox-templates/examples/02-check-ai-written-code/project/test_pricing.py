import unittest

from pricing import order_total


class OrderTotal(unittest.TestCase):
    def test_no_discount_below_100(self):
        self.assertEqual(order_total(10, 99), 990)

    def test_discount_at_exactly_100(self):
        self.assertEqual(order_total(10, 100), 900)

    def test_discount_above_100(self):
        self.assertEqual(order_total(10, 200), 1800)


if __name__ == "__main__":
    unittest.main()
