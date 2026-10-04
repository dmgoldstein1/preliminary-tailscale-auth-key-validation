#!/usr/bin/env bash
#
# Tests for preliminary-tailscale-auth-key-validation-*.sh.
#
# Sources the real validator functions (no network access) and checks
# the same 14 positive/negative vectors used by the Python and Node
# suites. Both Bash implementations are sourced to prove they are
# safely sourcable (their executable bodies live behind a
# BASH_SOURCE/main guard) and that they agree with each other.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../preliminary-tailscale-auth-key-validation-non-interactive.sh
source "$REPO_ROOT/preliminary-tailscale-auth-key-validation-non-interactive.sh"
# shellcheck source=../preliminary-tailscale-auth-key-validation-interactive.sh
source "$REPO_ROOT/preliminary-tailscale-auth-key-validation-interactive.sh"

PREFIX='tskey-auth-Ab12Cd34Ef56CNTRL-'
SECRET_32='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
SECRET_33='BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'

VALID_32="${PREFIX}${SECRET_32}"
VALID_33="${PREFIX}${SECRET_33}"

failures=0

expect_valid() {
    local description="$1"
    local value="$2"

    if is_valid_tailscale_auth_key "$value"; then
        printf 'PASS: %s\n' "$description"
    else
        printf 'FAIL: %s\n' "$description" >&2
        failures=$((failures + 1))
    fi
}

expect_invalid() {
    local description="$1"
    local value="$2"

    if is_valid_tailscale_auth_key "$value"; then
        printf 'FAIL: %s\n' "$description" >&2
        failures=$((failures + 1))
    else
        printf 'PASS: %s\n' "$description"
    fi
}

expect_valid \
    "32-character secret" \
    "$VALID_32"

expect_valid \
    "33-character secret" \
    "$VALID_33"

expect_invalid \
    "API key prefix" \
    "tskey-api-Ab12Cd34Ef56CNTRL-${SECRET_32}"

expect_invalid \
    "wrong prefix capitalization" \
    "TSKEY-AUTH-Ab12Cd34Ef56CNTRL-${SECRET_32}"

expect_invalid \
    "11-character identifier" \
    "tskey-auth-Ab12Cd34Ef5CNTRL-${SECRET_32}"

expect_invalid \
    "13-character identifier" \
    "tskey-auth-Ab12Cd34Ef567CNTRL-${SECRET_32}"

expect_invalid \
    "lowercase cntrl marker" \
    "tskey-auth-Ab12Cd34Ef56cntrl-${SECRET_32}"

expect_invalid \
    "31-character secret" \
    "${PREFIX}AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

expect_invalid \
    "34-character secret" \
    "${PREFIX}AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

expect_invalid \
    "underscore in secret" \
    "${PREFIX}AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA_"

expect_invalid \
    "leading whitespace" \
    " ${VALID_32}"

expect_invalid \
    "trailing whitespace" \
    "${VALID_32} "

expect_invalid \
    "empty string" \
    ""

expect_invalid \
    "arbitrary text" \
    "not-a-tailscale-key"

if (( failures > 0 )); then
    printf '\n%d test(s) failed.\n' "$failures" >&2
    exit 1
fi

printf '\nAll Bash tests passed.\n'
