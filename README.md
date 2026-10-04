# Tailscale Auth Key Validator

[![CI](https://github.com/dmgoldstein1/preliminary-tailscale-auth-key-validation/actions/workflows/ci.yml/badge.svg)](https://github.com/dmgoldstein1/preliminary-tailscale-auth-key-validation/actions/workflows/ci.yml)
![Python](https://img.shields.io/badge/Python-3.10%2B-blue)
![Node.js](https://img.shields.io/badge/Node.js-20%2B-green)
![Bash](https://img.shields.io/badge/Bash-3.2%2B-lightgrey)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![Network](https://img.shields.io/badge/network%20access-none-brightgreen)

**Offline structural validation for contemporary Tailscale authentication keys.**

This repository provides equivalent Tailscale auth-key validators in **Python**, **Node.js**, and **pure Bash**.

The validators perform no network requests and have no third-party dependencies. They are intended as a preliminary check before a candidate credential is ever transmitted to Tailscale.

## Features

- Fully offline validation
- No third-party dependencies
- Python, Node.js, and pure-Bash implementations
- Strict contemporary auth-key format checking
- Rejects other Tailscale credential types
- Rejects truncated or malformed keys
- Rejects whitespace and unexpected characters
- Suitable for installers, bootstrap scripts, CI/CD, containers, and provisioning systems
- Automated tests for all three implementations
- GitHub Actions CI

## Validation Rule

Contemporary Tailscale authentication keys have the following structure:

```text
tskey-auth-XXXXXXXXXXXXCNTRL-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
           12 chars                   32–33 chars
```

This project validates them with:

```regex
^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$
```

The same rule is implemented independently in Python, JavaScript, and Bash. The canonical expression is also stored in [`regex.txt`](./regex.txt).

A value must therefore contain:

| Component | Requirement |
|---|---|
| Prefix | `tskey-auth-` |
| Identifier | 12 alphanumeric characters |
| Marker | `CNTRL` |
| Separator | `-` |
| Secret | 32 or 33 alphanumeric characters |
| Extra characters | Not permitted |
| Whitespace | Not permitted |

Matching is case-sensitive.

## Important: Structural Validation Only

Passing this validator means:

> **This string has the expected structure of a contemporary Tailscale auth key.**

It does **not** mean that Tailscale has authenticated or accepted the credential.

Offline validation cannot determine whether the key:

- Was actually issued by Tailscale
- Has expired
- Has been revoked
- Has already been consumed if it is single-use
- Belongs to the intended tailnet
- Carries the expected tags
- Has the expected capabilities

Those properties can only be established by Tailscale's control plane.

The intended workflow is:

```text
                         ┌───────────────────┐
                         │ Candidate secret  │
                         └─────────┬─────────┘
                                   │
                                   ▼
                       ┌───────────────────────┐
                       │ Local format validator │
                       └───────────┬───────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                 invalid                       valid
                    │                             │
                    ▼                             ▼
             Reject locally              Send to Tailscale
                                                  │
                                      ┌───────────┴───────────┐
                                      │                       │
                                   rejected                accepted
```

Malformed or obviously inappropriate values never need to leave the machine.

## Repository Layout

```text
.
├── .github/
│   └── workflows/
│       └── ci.yml
├── tests/
│   ├── run-all.sh
│   ├── test_bash.sh
│   ├── test_node.js
│   └── test_python.py
├── preliminary-tailscale-auth-key-validation-interactive.sh
├── preliminary-tailscale-auth-key-validation-non-interactive.sh
├── preliminary-tailscale-auth-key-validation.js
├── preliminary-tailscale-auth-key-validation.py
├── regex.txt
├── Validate-Tailscale-Auth-Key-chat.md
└── README.md
```

The implementations all use the same validation rule. The two Bash variants share the same `is_valid_tailscale_auth_key` function and differ only in how they obtain the candidate value (hidden interactive prompt vs. `TS_AUTH_KEY` environment variable). `Validate-Tailscale-Auth-Key-chat.md` is the design conversation from which this repository was derived.

## Installation

No package installation is required.

Clone the repository:

```bash
git clone https://github.com/dmgoldstein1/preliminary-tailscale-auth-key-validation.git
cd preliminary-tailscale-auth-key-validation
```

Then use whichever implementation is appropriate for the host environment.

You can also copy a single implementation into another project. Each validator is self-contained.

## Python

### Requirements

Python 3.10 or later.

No PyPI packages are required.

### Interactive Usage

```bash
python3 preliminary-tailscale-auth-key-validation.py
```

The key is requested without being displayed on screen:

```text
Tailscale auth key:
Structurally valid contemporary Tailscale auth key.
```

Malformed input returns:

```text
Tailscale auth key:
Invalid Tailscale auth key format.
```

### As a Python Function

The validator can also be imported. Because the filename contains hyphens, load it with `importlib`:

```python
import importlib.util

spec = importlib.util.spec_from_file_location(
    "tailscale_auth_key_validator",
    "preliminary-tailscale-auth-key-validation.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

if module.is_valid_tailscale_auth_key(candidate):
    print("Structurally valid")
else:
    print("Invalid")
```

This performs no network access. The CLI prompt only runs when the file is executed directly (`if __name__ == "__main__"` guard).

## Node.js

### Requirements

Node.js 20 or later.

No npm installation is required.

### Usage

Provide the credential through `TS_AUTH_KEY`:

```bash
export TS_AUTH_KEY='tskey-auth-...'
node preliminary-tailscale-auth-key-validation.js
```

Successful validation returns:

```text
Structurally valid contemporary Tailscale auth key.
```

Malformed input returns:

```text
Invalid Tailscale auth key format.
```

### As a JavaScript Function

The function can be imported with CommonJS:

```javascript
const {
    isValidTailscaleAuthKey
} = require("./preliminary-tailscale-auth-key-validation.js");

if (isValidTailscaleAuthKey(candidate)) {
    console.log("Structurally valid");
}
```

No npm packages are required. The CLI only runs when the file is the entry point (`require.main === module` guard).

## Bash

### Requirements

Bash 3.2 or later.

The implementation uses Bash's built-in regular-expression matching:

```bash
[[ "$value" =~ $regex ]]
```

It does not invoke:

```text
grep
sed
awk
perl
python
node
```

### Interactive Usage

```bash
chmod +x preliminary-tailscale-auth-key-validation-interactive.sh
./preliminary-tailscale-auth-key-validation-interactive.sh
```

The key is read with `read -r -s` so it is not echoed, then validated. The secret variable is `unset` immediately afterwards.

### Environment Variable Usage

Set the credential:

```bash
export TS_AUTH_KEY='tskey-auth-...'
```

Then run:

```bash
chmod +x preliminary-tailscale-auth-key-validation-non-interactive.sh
./preliminary-tailscale-auth-key-validation-non-interactive.sh
```

The validation function can also be sourced by another Bash script (both scripts guard their executable bodies with a `BASH_SOURCE` check, so sourcing has no side effects):

```bash
source ./preliminary-tailscale-auth-key-validation-non-interactive.sh

if is_valid_tailscale_auth_key "$candidate"; then
    echo "Structurally valid"
fi
```

## Exit Codes

The command-line implementations use conventional exit statuses:

| Exit code | Meaning |
|---:|---|
| `0` | Structurally valid |
| `1` | Invalid format |
| `2` | Required input was not supplied |

This makes the validators suitable for automation:

```bash
if ./preliminary-tailscale-auth-key-validation-non-interactive.sh; then
    echo "Local validation passed."
else
    echo "Refusing malformed credential."
    exit 1
fi
```

## Tests

The repository includes automated tests for each implementation.

The tests deliberately use **synthetic credentials** that match the format but are not intended to be real Tailscale credentials.

Test cases include:

| Test | Expected result |
|---|---|
| 32-character secret | Accept |
| 33-character secret | Accept |
| Wrong `tskey-api-` prefix | Reject |
| Wrong prefix capitalization | Reject |
| 11-character identifier | Reject |
| 13-character identifier | Reject |
| Lowercase `cntrl` | Reject |
| 31-character secret | Reject |
| 34-character secret | Reject |
| Underscore in secret | Reject |
| Leading whitespace | Reject |
| Trailing whitespace | Reject |
| Empty string | Reject |
| Arbitrary text | Reject |

### Run Everything

From the repository root:

```bash
bash tests/run-all.sh
```

Expected output resembles:

```text
==> Python tests
..............
----------------------------------------------------------------------
Ran 14 tests

OK

==> Node.js tests
✔ accepts a 32-character secret
✔ accepts a 33-character secret
...

==> Bash tests
PASS: 32-character secret
PASS: 33-character secret
...

All validator test suites passed.
```

### Python Only

```bash
python3 -m unittest tests/test_python.py
```

### Node.js Only

```bash
node --test tests/test_node.js
```

Node's built-in test runner is used, so no test framework needs to be installed.

### Bash Only

```bash
bash tests/test_bash.sh
```

## CI Test Matrix

GitHub Actions automatically runs the validators across multiple supported runtimes.

| Implementation | CI environments |
|---|---|
| Python | Python 3.10, 3.12, 3.14 on Ubuntu |
| Node.js | Node.js 20, 22, 24 on Ubuntu |
| Bash | Ubuntu and macOS |
| Dependencies | None |

CI runs automatically for pushes and pull requests.

## Security Considerations

### Treat Auth Keys as Secrets

Tailscale authentication keys are credentials.

Do not log them, commit them to source control, include them in bug reports, or expose them in CI output.

Bad:

```text
Received auth key: tskey-auth-...
```

Better:

```text
Auth key passed local structural validation.
```

### Avoid Command-Line Arguments

Avoid supplying credentials directly as command-line arguments:

```bash
./validator tskey-auth-...
```

Command-line arguments can sometimes be exposed through:

- Shell history
- Process listings
- Monitoring tools
- Debugging tools
- CI logs

Prefer an environment variable, secret manager, protected file descriptor, or hidden interactive input.

### Do Not Automatically Repair Credentials

These validators intentionally do not:

- Trim whitespace
- Change capitalization
- Remove punctuation
- Correct prefixes
- Attempt to reconstruct truncated credentials

Credentials should be checked exactly as supplied.

For example:

```text
 tskey-auth-...
```

is rejected rather than silently converted into:

```text
tskey-auth-...
```

This makes failures explicit and avoids accidentally altering secret material.

### Never Commit Real Test Credentials

The automated tests use synthetic strings generated solely to satisfy or violate the structural format.

Do not replace them with real auth keys.

If a real credential is accidentally committed to a Git repository, treat it as compromised and revoke it.

## Why Use Preliminary Validation?

Local structural validation is useful anywhere a program accepts a Tailscale credential before subsequently using it for enrollment.

Examples include:

- Machine bootstrap scripts
- Cloud-init
- Infrastructure provisioning
- Container entrypoints
- CI/CD pipelines
- Configuration-management systems
- Web applications
- Secret-management workflows
- Automated installers
- Appliance setup interfaces

It can immediately catch errors such as supplying:

```text
tskey-api-...
```

instead of:

```text
tskey-auth-...
```

or accidentally supplying a truncated credential, pasted whitespace, malformed secret, or arbitrary input.

This reduces unnecessary authentication requests and allows applications to provide useful validation errors locally.

## Design Goals

This project intentionally stays small.

Each implementation should remain:

**Offline.** Validation must never require contacting Tailscale.

**Dependency-free.** Standard language/runtime facilities should be sufficient.

**Strict.** Malformed credentials should fail closed rather than be repaired.

**Auditable.** The validation logic should remain simple enough to inspect at a glance.

**Consistent.** Python, JavaScript, and Bash should accept and reject the same input.

## Compatibility

This project intentionally targets the **contemporary Tailscale auth-key format**.

It does not attempt to recognize every historical Tailscale credential format.

If Tailscale changes the auth-key format in the future, the validators and corresponding test vectors will need to be updated together.

The current expressions are:

### Python

```python
r"^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$"
```

### JavaScript

```javascript
/^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$/
```

### Bash

```bash
'^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$'
```

Any format change should include corresponding changes to all implementations and their automated tests.

## Contributing

Changes are welcome, particularly when they improve consistency or identify a change in Tailscale's contemporary credential format.

Before submitting a pull request:

```bash
bash tests/run-all.sh
```

All three validator suites should pass.

Changes to the validation rule should include new positive and negative test vectors demonstrating the intended behavior.

## License

MIT — see [`LICENSE`](./LICENSE).
