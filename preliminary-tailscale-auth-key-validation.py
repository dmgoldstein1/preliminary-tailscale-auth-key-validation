#!/usr/bin/env python3

import re
import getpass

TAILSCALE_AUTH_KEY_RE = re.compile(
    r"^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$"
)

def is_valid_tailscale_auth_key(key: str) -> bool:
    return (
        isinstance(key, str)
        and TAILSCALE_AUTH_KEY_RE.fullmatch(key) is not None
    )


def main() -> int:
    key = getpass.getpass("Tailscale auth key: ")

    if is_valid_tailscale_auth_key(key):
        print("Structurally valid contemporary Tailscale auth key.")
        return 0

    print("Invalid Tailscale auth key format.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())