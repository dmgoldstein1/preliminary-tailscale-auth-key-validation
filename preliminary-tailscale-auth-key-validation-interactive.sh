#!/usr/bin/env bash

is_valid_tailscale_auth_key() {
    local key="$1"
    local regex='^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$'

    [[ "$key" =~ $regex ]]
}

read -r -s -p "Tailscale auth key: " key
printf '\n'

if is_valid_tailscale_auth_key "$key"; then
    echo "Structurally valid contemporary Tailscale auth key."
    unset key
    exit 0
else
    echo "Invalid Tailscale auth key format." >&2
    unset key
    exit 1
fi