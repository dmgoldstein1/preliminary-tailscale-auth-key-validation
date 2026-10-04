#!/usr/bin/env bash

is_valid_tailscale_auth_key() {
    local key="$1"
    local regex='^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$'

    [[ "$key" =~ $regex ]]
}


if [[ -z "${TS_AUTH_KEY:-}" ]]; then
    echo "TS_AUTH_KEY is not set." >&2
    exit 2
fi

if is_valid_tailscale_auth_key "$TS_AUTH_KEY"; then
    echo "Structurally valid contemporary Tailscale auth key."
    exit 0
else
    echo "Invalid Tailscale auth key format." >&2
    exit 1
fi