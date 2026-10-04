#!/usr/bin/env bash

is_valid_tailscale_auth_key() {
    local key="$1"
    local regex='^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$'

    [[ "$key" =~ $regex ]]
}


main() {
    if [[ -z "${TS_AUTH_KEY:-}" ]]; then
        echo "TS_AUTH_KEY is not set." >&2
        return 2
    fi

    if is_valid_tailscale_auth_key "$TS_AUTH_KEY"; then
        echo "Structurally valid contemporary Tailscale auth key."
        return 0
    fi

    echo "Invalid Tailscale auth key format." >&2
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
    exit $?
fi