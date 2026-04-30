import unittest
from utils import get_config


class TestUtils(unittest.TestCase):
    def test_get_config_debug(self):
        result = get_config("debug")
        self.assertIn("debug", result)


if __name__ == "__main__":
    unittest.main()
