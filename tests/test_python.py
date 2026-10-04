"""Tests for preliminary-tailscale-auth-key-validation.py.

Loads the validator via importlib because the implementation filename
contains hyphens and therefore cannot be imported with a plain
``import`` statement. The tests exercise the real production function.
"""

import importlib.util
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
VALIDATOR_PATH = (
    REPO_ROOT / "preliminary-tailscale-auth-key-validation.py"
)


def _load_validator():
    spec = importlib.util.spec_from_file_location(
        "tailscale_auth_key_validator", VALIDATOR_PATH
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_validator = _load_validator()
is_valid_tailscale_auth_key = _validator.is_valid_tailscale_auth_key

PREFIX = "tskey-auth-Ab12Cd34Ef56CNTRL-"
VALID_32 = PREFIX + ("A" * 32)
VALID_33 = PREFIX + ("B" * 33)


class TailscaleAuthKeyValidatorTests(unittest.TestCase):
    def test_accepts_32_character_secret(self):
        self.assertTrue(is_valid_tailscale_auth_key(VALID_32))

    def test_accepts_33_character_secret(self):
        self.assertTrue(is_valid_tailscale_auth_key(VALID_33))

    def test_rejects_api_key_prefix(self):
        value = VALID_32.replace("tskey-auth-", "tskey-api-", 1)
        self.assertFalse(is_valid_tailscale_auth_key(value))

    def test_rejects_wrong_prefix_case(self):
        value = VALID_32.replace("tskey-auth-", "TSKEY-AUTH-", 1)
        self.assertFalse(is_valid_tailscale_auth_key(value))

    def test_rejects_short_identifier(self):
        value = "tskey-auth-Ab12Cd34Ef5CNTRL-" + ("A" * 32)
        self.assertFalse(is_valid_tailscale_auth_key(value))

    def test_rejects_long_identifier(self):
        value = "tskey-auth-Ab12Cd34Ef567CNTRL-" + ("A" * 32)
        self.assertFalse(is_valid_tailscale_auth_key(value))

    def test_rejects_lowercase_cntrl(self):
        value = VALID_32.replace("CNTRL", "cntrl")
        self.assertFalse(is_valid_tailscale_auth_key(value))

    def test_rejects_31_character_secret(self):
        value = PREFIX + ("A" * 31)
        self.assertFalse(is_valid_tailscale_auth_key(value))

    def test_rejects_34_character_secret(self):
        value = PREFIX + ("A" * 34)
        self.assertFalse(is_valid_tailscale_auth_key(value))

    def test_rejects_underscore(self):
        value = PREFIX + ("A" * 31) + "_"
        self.assertFalse(is_valid_tailscale_auth_key(value))

    def test_rejects_leading_whitespace(self):
        self.assertFalse(is_valid_tailscale_auth_key(" " + VALID_32))

    def test_rejects_trailing_whitespace(self):
        self.assertFalse(is_valid_tailscale_auth_key(VALID_32 + " "))

    def test_rejects_empty_string(self):
        self.assertFalse(is_valid_tailscale_auth_key(""))

    def test_rejects_arbitrary_text(self):
        self.assertFalse(is_valid_tailscale_auth_key("not-a-tailscale-key"))


if __name__ == "__main__":
    unittest.main()
