> From: https://chatgpt.com/c/6ac2e3c0-f958-83ea-93a6-0af49ecc7599

# you asked

message time: 2026-10-04 19:39:44

Is there a way to preliminarily validate a Tailscale auth key before sending it to Tailscale?

---

# chatgpt response

Yes—at least partially. You can validate the key’s **shape/encoding locally** and reject obvious garbage before ever making a Tailscale API/control-plane request; what you cannot determine offline is whether the key is actually valid, expired, revoked, or usable in that tailnet.

Yes. You can do a useful **offline sanity check**, but not a definitive validity check.

Modern Tailscale auth keys use the `tskey-auth-` prefix, are case-sensitive, and consist of ASCII letters, digits, and hyphens. Tailscale documents `tskey-auth` specifically as the prefix for pre-authentication keys. ([Tailscale](https://tailscale.com/docs/reference/key-prefixes?utm_source=chatgpt.com))

For example, before allowing your application to send a candidate key anywhere, you could validate it like this:

```python
import re

def looks_like_tailscale_auth_key(key: str) -> bool:
    if not isinstance(key, str):
        return False

    # Don't silently fix whitespace on a secret.
    if key != key.strip():
        return False

    if not key.startswith("tskey-auth-"):
        return False

    # Tailscale keys consist of alphanumerics and hyphens.
    if not re.fullmatch(r"tskey-auth-[A-Za-z0-9-]+", key):
        return False

    # Reject obviously truncated input.
    if len(key) < 30:
        return False

    return True
```

I would **not** make the regex substantially stricter than that. Tailscale has changed key formats over time. Current documentation gives examples resembling:

```text
tskey-auth-abcDEF1CNTRL-091234567890ABCDEF
```

while older real auth keys used somewhat different layouts. ([Tailscale](https://tailscale.com/docs/reference/key-prefixes?utm_source=chatgpt.com)) So hard-coding exact segment lengths risks rejecting legitimate keys after a Tailscale format change.

There is an important distinction between what you can and cannot establish locally:

| Check | Offline? |
|---|---:|
| Starts with `tskey-auth-` | ✅ |
| Contains only plausible characters | ✅ |
| Isn't blank/truncated/whitespace-contaminated | ✅ |
| Isn't accidentally an API/OAuth key | ✅ |
| Cryptographically authentic | ❌ |
| Exists in Tailscale | ❌ |
| Not revoked | ❌ |
| Not expired | ❌ |
| Not already consumed if single-use | ❌ |
| Has the required tags/capabilities | ❌ |

Those latter properties exist on Tailscale's control plane. An invalid key ultimately results in a server-side rejection such as `invalid key: API key ... not valid`, demonstrating that actual validity is determined during registration. ([GitHub](https://github.com/tailscale/tailscale/issues/9715?utm_source=chatgpt.com))

One particularly worthwhile local check is to reject other Tailscale credential types:

```python
if key.startswith("tskey-") and not key.startswith("tskey-auth-"):
    raise ValueError("This is a Tailscale key, but not an auth key.")
```

That catches someone accidentally supplying a `tskey-api-...`, `tskey-client-...`, `tskey-scim-...`, or `tskey-webhook-...` secret. Those prefixes are officially defined by Tailscale. ([Tailscale](https://tailscale.com/docs/reference/key-prefixes?utm_source=chatgpt.com))

If your underlying objective is **validating user input without leaking arbitrary strings to Tailscale**, I'd use the permissive structural check above first and only contact the Tailscale control plane after it passes. There does not appear to be a cryptographic signature/checksum embedded in an auth key that lets a third party prove offline that Tailscale issued it; it functions essentially as an opaque bearer secret.

---

# you asked

message time: 2026-10-04 19:41:22

Actually, this process only needs to work with contemporary keys. Please provide a script in python, Javascript for node.js as well as pure bash.

---

# chatgpt response

Since you only need **current-format** keys, I can make the check much stricter than before. I’m verifying the contemporary segment lengths and marker rather than just checking for `tskey-auth-`.

Yes. Since you're intentionally targeting **contemporary Tailscale auth keys only**, I'd use this strict structural pattern:

```regex
^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$
```

Tailscale documents `tskey-auth` as the prefix for pre-authentication keys and specifies that its keys are case-sensitive. ([Tailscale](https://tailscale.com/docs/reference/key-prefixes?utm_source=chatgpt.com)) The exact strict pattern above is also used by GitLab's contemporary secret-detection rules for Tailscale personal auth keys. ([Diffend](https://my.diffend.io/gems/gitlab-secret_detection/0.37.1/0.38.1?utm_source=chatgpt.com))

This means the expected structure is:

```text
tskey-auth-XXXXXXXXXXXXCNTRL-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
           12 chars           32 or 33 chars
```

These validators perform **zero network access**.

### Python

```python
#!/usr/bin/env python3

import re

TAILSCALE_AUTH_KEY_RE = re.compile(
    r"^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$"
)

def is_valid_tailscale_auth_key(key: str) -> bool:
    if not isinstance(key, str):
        return False

    return TAILSCALE_AUTH_KEY_RE.fullmatch(key) is not None


# Example
key = input("Tailscale auth key: ")

if is_valid_tailscale_auth_key(key):
    print("Structurally valid contemporary Tailscale auth key.")
else:
    print("Invalid Tailscale auth key format.")
```

If this is being used in an application where you don't want the key displayed while typing:

```python
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


key = getpass.getpass("Tailscale auth key: ")

if not is_valid_tailscale_auth_key(key):
    raise SystemExit("Invalid Tailscale auth key format.")

print("Structurally valid.")
```

### Node.js / JavaScript

```javascript
#!/usr/bin/env node

const TAILSCALE_AUTH_KEY_RE =
    /^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$/;

function isValidTailscaleAuthKey(key) {
    return (
        typeof key === "string" &&
        TAILSCALE_AUTH_KEY_RE.test(key)
    );
}


// Example
const key = process.env.TS_AUTH_KEY;

if (!key) {
    console.error("TS_AUTH_KEY is not set.");
    process.exit(2);
}

if (isValidTailscaleAuthKey(key)) {
    console.log("Structurally valid contemporary Tailscale auth key.");
    process.exit(0);
} else {
    console.error("Invalid Tailscale auth key format.");
    process.exit(1);
}
```

Using an environment variable here avoids putting the secret directly into the command line:

```bash
export TS_AUTH_KEY='...'
node validate-tailscale-key.js
```

### Pure Bash

This version uses only Bash built-ins—no `grep`, `sed`, `awk`, Python, etc.

```bash
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
```

Or, for an interactive **pure-Bash** version that doesn't echo the secret as it is entered:

```bash
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
```

I would use exactly this level of validation for your purpose: it will reject truncated keys, API tokens (`tskey-api-...`), OAuth secrets, whitespace, punctuation, wrong capitalization of `CNTRL`, malformed IDs, and incorrectly sized secrets **before any request leaves the machine**.

It still intentionally means only **“this looks exactly like a contemporary Tailscale auth key.”** It cannot establish offline whether the key exists, belongs to the intended tailnet, has expired, has been revoked, or—if one-time-use—has already been consumed. Those require Tailscale's control plane.

---

# you asked

message time: 2026-10-04 19:46:22

Write a README.md for a repo which contains these files

---

# chatgpt response

Here’s a README you can drop into the repository.

> **Document: README.md**
> 
> # Tailscale Auth Key Validator
> 
> Offline structural validation for contemporary Tailscale authentication keys.
> 
> This repository contains equivalent validators written in:
> 
> - Python
> - Node.js / JavaScript
> - Pure Bash
> 
> The validators perform **no network requests**. They are intended to reject malformed input before a candidate authentication key is ever sent to Tailscale.
> 
> ## What It Validates
> 
> The scripts check whether a supplied value matches the contemporary Tailscale authentication-key format:
> 
> ```text
> tskey-auth-XXXXXXXXXXXXCNTRL-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
> ```
> 
> The validation rule is:
> 
> ```regex
> ^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$
> ```
> 
> This checks for:
> 
> - The `tskey-auth-` prefix
> - A 12-character alphanumeric identifier
> - The `CNTRL` marker
> - A 32- or 33-character alphanumeric secret
> - Correct capitalization
> - No whitespace
> - No extra leading or trailing characters
> - No punctuation or unexpected characters
> 
> This also prevents other Tailscale credential types, such as API or OAuth credentials, from accidentally being accepted as auth keys.
> 
> ## What It Does Not Validate
> 
> These scripts perform only **local structural validation**.
> 
> A key that passes validation is not necessarily usable.
> 
> Without contacting the Tailscale control plane, the validator cannot determine whether a key:
> 
> - Was actually issued by Tailscale
> - Has expired
> - Has been revoked
> - Has already been consumed if it is single-use
> - Belongs to the expected tailnet
> - Has the expected tags or permissions
> 
> A successful result therefore means:
> 
> > This string has the expected structure of a contemporary Tailscale auth key.
> 
> It does **not** mean:
> 
> > Tailscale has confirmed this key is valid.
> 
> ## Repository Contents
> 
> ```text
> .
> ├── validate_tailscale_key.py
> ├── validate-tailscale-key.js
> ├── validate-tailscale-key.sh
> └── README.md
> ```
> 
> The three implementations use the same validation rule.
> 
> ## Python
> 
> ### Requirements
> 
> Python 3.
> 
> No third-party packages are required.
> 
> ### Usage
> 
> Run:
> 
> ```bash
> python3 validate_tailscale_key.py
> ```
> 
> The script prompts for the auth key without displaying it on screen.
> 
> Example:
> 
> ```text
> Tailscale auth key:
> Structurally valid.
> ```
> 
> For invalid input:
> 
> ```text
> Tailscale auth key:
> Invalid Tailscale auth key format.
> ```
> 
> ## Node.js
> 
> ### Requirements
> 
> Node.js.
> 
> No npm packages are required.
> 
> ### Usage
> 
> Provide the key through the `TS_AUTH_KEY` environment variable:
> 
> ```bash
> export TS_AUTH_KEY='tskey-auth-...'
> node validate-tailscale-key.js
> ```
> 
> A valid-looking key returns:
> 
> ```text
> Structurally valid contemporary Tailscale auth key.
> ```
> 
> Malformed input returns:
> 
> ```text
> Invalid Tailscale auth key format.
> ```
> 
> ### Exit Codes
> 
> The Node.js implementation uses:
> 
> ```text
> 0   Structurally valid
> 1   Invalid key format
> 2   TS_AUTH_KEY was not supplied
> ```
> 
> This makes it suitable for shell scripts, CI workflows, installers, and other automation.
> 
> For example:
> 
> ```bash
> if node validate-tailscale-key.js; then
>     echo "Key passed local validation."
> else
>     echo "Key rejected."
> fi
> ```
> 
> ## Bash
> 
> ### Requirements
> 
> Bash.
> 
> The validator uses Bash's built-in `[[ ... =~ ... ]]` regular-expression matching and does not require utilities such as:
> 
> - `grep`
> - `sed`
> - `awk`
> - Python
> - Perl
> 
> ### Environment Variable Usage
> 
> Set the key:
> 
> ```bash
> export TS_AUTH_KEY='tskey-auth-...'
> ```
> 
> Then run:
> 
> ```bash
> ./validate-tailscale-key.sh
> ```
> 
> You may need to make the script executable first:
> 
> ```bash
> chmod +x validate-tailscale-key.sh
> ```
> 
> ### Exit Codes
> 
> The Bash implementation uses:
> 
> ```text
> 0   Structurally valid
> 1   Invalid key format
> 2   TS_AUTH_KEY was not supplied
> ```
> 
> It can therefore be used directly as a prerequisite for another command:
> 
> ```bash
> if ./validate-tailscale-key.sh; then
>     echo "Proceeding with Tailscale enrollment."
> else
>     echo "Refusing malformed auth key."
>     exit 1
> fi
> ```
> 
> ## Example Integration
> 
> A typical enrollment workflow might look like:
> 
> ```text
> User or secret store
>         │
>         ▼
> Local auth-key validator
>         │
>         ├── malformed ──► reject locally
>         │
>         ▼
> structurally valid
>         │
>         ▼
> Tailscale
>         │
>         ├── expired/revoked/invalid ──► reject
>         │
>         ▼
> successful enrollment
> ```
> 
> The local validator is intended to prevent obviously incorrect values from reaching the network at all.
> 
> It is not a replacement for Tailscale's own authentication checks.
> 
> ## Security Considerations
> 
> ### Do Not Put Auth Keys Directly on the Command Line
> 
> Avoid commands such as:
> 
> ```bash
> node validate-tailscale-key.js tskey-auth-...
> ```
> 
> Command-line arguments may be exposed through:
> 
> - Shell history
> - Process listings
> - Debugging tools
> - Logging systems
> 
> Prefer environment variables, secret stores, or interactive hidden input.
> 
> For example:
> 
> ```bash
> export TS_AUTH_KEY='...'
> ```
> 
> or use a secret-management mechanism appropriate to the environment.
> 
> ### Do Not Log Auth Keys
> 
> A Tailscale auth key is a credential and should be treated as a secret.
> 
> Applications using these validators should avoid logging:
> 
> ```text
> Received key: tskey-auth-...
> ```
> 
> Log the result instead:
> 
> ```text
> Tailscale auth key passed structural validation.
> ```
> 
> ### Avoid "Helpful" String Modification
> 
> The validators deliberately do not:
> 
> - Trim whitespace
> - Convert case
> - Remove punctuation
> - Attempt to repair malformed keys
> 
> Credential validation should fail closed rather than silently modifying a supplied secret.
> 
> For example, this:
> 
> ```text
>  tskey-auth-...
> ```
> 
> should be rejected rather than automatically trimmed.
> 
> ## Why Validate Locally?
> 
> Local validation can be useful when accepting auth keys through:
> 
> - Installation scripts
> - Provisioning systems
> - Web applications
> - Configuration files
> - Infrastructure automation
> - Container entrypoints
> - CI/CD systems
> - Bootstrap scripts
> 
> It can catch errors such as:
> 
> ```text
> tskey-api-...
> ```
> 
> instead of an auth key,
> 
> a truncated value:
> 
> ```text
> tskey-auth-abc...
> ```
> 
> a pasted value containing whitespace:
> 
> ```text
> tskey-auth-... 
> ```
> 
> or arbitrary input:
> 
> ```text
> not-a-tailscale-key
> ```
> 
> without transmitting those values to Tailscale.
> 
> ## Compatibility
> 
> These validators intentionally target the **contemporary Tailscale auth-key format** rather than attempting to support historical formats.
> 
> If Tailscale changes its authentication-key format in the future, the regular expression may need to be updated.
> 
> The validation rule is defined independently in each implementation:
> 
> ### Python
> 
> ```python
> r"^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$"
> ```
> 
> ### JavaScript
> 
> ```javascript
> /^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$/
> ```
> 
> ### Bash
> 
> ```bash
> '^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$'
> ```
> 
> When changing the accepted format, update all three implementations together.
> 
> ## License
> 
> Add the license appropriate for your project here.

If you want, I can also make this more like a polished open-source GitHub README, with badges, a test matrix, installation examples, and a small automated test suite for all three implementations.

---

# you asked

message time: 2026-10-04 19:48:46

Yes, make it more like a polished open-source GitHub README with badges, a test matrix, installation examples, and a small automated test suite for all three implementations.

---

# chatgpt response

I’ll make the repository presentation coherent rather than just decorating the README: the test suite will exercise the actual validators, use only standard runtimes, and include a GitHub Actions workflow so the CI badge is meaningful. Since I don’t know the GitHub owner/repo name, I’ll use `YOUR_USERNAME/YOUR_REPO` placeholders in badge URLs.

One implementation detail matters for CI: the existing Python and Node files execute their CLI code immediately when imported, and the Bash file executes when sourced. The tests should exercise the validators’ real functions, so I’m structuring the README around adding standard “run only when executed directly” guards; that keeps normal CLI behavior unchanged while making the code testable.

Below is a more complete repository setup. The README assumes the repository is public on GitHub; replace `YOUR_USERNAME/YOUR_REPO` in the CI badge once you create it.

> **Document: README.md**
> 
> # Tailscale Auth Key Validator
> 
> [![CI](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml)
> ![Python](https://img.shields.io/badge/Python-3.10%2B-blue)
> ![Node.js](https://img.shields.io/badge/Node.js-20%2B-green)
> ![Bash](https://img.shields.io/badge/Bash-3.2%2B-lightgrey)
> ![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
> ![Network](https://img.shields.io/badge/network%20access-none-brightgreen)
> 
> **Offline structural validation for contemporary Tailscale authentication keys.**
> 
> This repository provides equivalent Tailscale auth-key validators in **Python**, **Node.js**, and **pure Bash**.
> 
> The validators perform no network requests and have no third-party dependencies. They are intended as a preliminary check before a candidate credential is ever transmitted to Tailscale.
> 
> ## Features
> 
> - Fully offline validation
> - No third-party dependencies
> - Python, Node.js, and pure-Bash implementations
> - Strict contemporary auth-key format checking
> - Rejects other Tailscale credential types
> - Rejects truncated or malformed keys
> - Rejects whitespace and unexpected characters
> - Suitable for installers, bootstrap scripts, CI/CD, containers, and provisioning systems
> - Automated tests for all three implementations
> - GitHub Actions CI
> 
> ## Validation Rule
> 
> Contemporary Tailscale authentication keys have the following structure:
> 
> ```text
> tskey-auth-XXXXXXXXXXXXCNTRL-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
>            12 chars                   32–33 chars
> ```
> 
> This project validates them with:
> 
> ```regex
> ^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$
> ```
> 
> The same rule is implemented independently in Python, JavaScript, and Bash.
> 
> A value must therefore contain:
> 
> | Component | Requirement |
> |---|---|
> | Prefix | `tskey-auth-` |
> | Identifier | 12 alphanumeric characters |
> | Marker | `CNTRL` |
> | Separator | `-` |
> | Secret | 32 or 33 alphanumeric characters |
> | Extra characters | Not permitted |
> | Whitespace | Not permitted |
> 
> Matching is case-sensitive.
> 
> ## Important: Structural Validation Only
> 
> Passing this validator means:
> 
> > **This string has the expected structure of a contemporary Tailscale auth key.**
> 
> It does **not** mean that Tailscale has authenticated or accepted the credential.
> 
> Offline validation cannot determine whether the key:
> 
> - Was actually issued by Tailscale
> - Has expired
> - Has been revoked
> - Has already been consumed if it is single-use
> - Belongs to the intended tailnet
> - Carries the expected tags
> - Has the expected capabilities
> 
> Those properties can only be established by Tailscale's control plane.
> 
> The intended workflow is:
> 
> ```text
>                          ┌───────────────────┐
>                          │ Candidate secret  │
>                          └─────────┬─────────┘
>                                    │
>                                    ▼
>                        ┌───────────────────────┐
>                        │ Local format validator │
>                        └───────────┬───────────┘
>                                    │
>                     ┌──────────────┴──────────────┐
>                     │                             │
>                  invalid                       valid
>                     │                             │
>                     ▼                             ▼
>              Reject locally              Send to Tailscale
>                                                   │
>                                       ┌───────────┴───────────┐
>                                       │                       │
>                                    rejected                accepted
> ```
> 
> Malformed or obviously inappropriate values never need to leave the machine.
> 
> ## Repository Layout
> 
> ```text
> .
> ├── .github/
> │   └── workflows/
> │       └── ci.yml
> ├── tests/
> │   ├── run-all.sh
> │   ├── test_bash.sh
> │   ├── test_node.js
> │   └── test_python.py
> ├── validate-tailscale-key.js
> ├── validate-tailscale-key.sh
> ├── validate_tailscale_key.py
> └── README.md
> ```
> 
> ## Installation
> 
> No package installation is required.
> 
> Clone the repository:
> 
> ```bash
> git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
> cd YOUR_REPO
> ```
> 
> Then use whichever implementation is appropriate for the host environment.
> 
> You can also copy a single implementation into another project. Each validator is self-contained.
> 
> ## Python
> 
> ### Requirements
> 
> Python 3.10 or later.
> 
> No PyPI packages are required.
> 
> ### Interactive Usage
> 
> ```bash
> python3 validate_tailscale_key.py
> ```
> 
> The key is requested without being displayed on screen:
> 
> ```text
> Tailscale auth key:
> Structurally valid contemporary Tailscale auth key.
> ```
> 
> Malformed input returns:
> 
> ```text
> Invalid Tailscale auth key format.
> ```
> 
> ### As a Python Function
> 
> The validator can also be imported:
> 
> ```python
> from validate_tailscale_key import is_valid_tailscale_auth_key
> 
> if is_valid_tailscale_auth_key(candidate):
>     print("Structurally valid")
> else:
>     print("Invalid")
> ```
> 
> This performs no network access.
> 
> ## Node.js
> 
> ### Requirements
> 
> Node.js 20 or later.
> 
> No npm installation is required.
> 
> ### Usage
> 
> Provide the credential through `TS_AUTH_KEY`:
> 
> ```bash
> export TS_AUTH_KEY='tskey-auth-...'
> node validate-tailscale-key.js
> ```
> 
> Successful validation returns:
> 
> ```text
> Structurally valid contemporary Tailscale auth key.
> ```
> 
> Malformed input returns:
> 
> ```text
> Invalid Tailscale auth key format.
> ```
> 
> ### As a JavaScript Function
> 
> The function can be imported with CommonJS:
> 
> ```javascript
> const {
>     isValidTailscaleAuthKey
> } = require("./validate-tailscale-key.js");
> 
> if (isValidTailscaleAuthKey(candidate)) {
>     console.log("Structurally valid");
> }
> ```
> 
> No npm packages are required.
> 
> ## Bash
> 
> ### Requirements
> 
> Bash 3.2 or later.
> 
> The implementation uses Bash's built-in regular-expression matching:
> 
> ```bash
> [[ "$value" =~ $regex ]]
> ```
> 
> It does not invoke:
> 
> ```text
> grep
> sed
> awk
> perl
> python
> node
> ```
> 
> ### Usage
> 
> Make the script executable:
> 
> ```bash
> chmod +x validate-tailscale-key.sh
> ```
> 
> Set the credential:
> 
> ```bash
> export TS_AUTH_KEY='tskey-auth-...'
> ```
> 
> Run:
> 
> ```bash
> ./validate-tailscale-key.sh
> ```
> 
> The validation function can also be sourced by another Bash script:
> 
> ```bash
> source ./validate-tailscale-key.sh
> 
> if is_valid_tailscale_auth_key "$candidate"; then
>     echo "Structurally valid"
> fi
> ```
> 
> ## Exit Codes
> 
> The command-line implementations use conventional exit statuses:
> 
> | Exit code | Meaning |
> |---:|---|
> | `0` | Structurally valid |
> | `1` | Invalid format |
> | `2` | Required input was not supplied |
> 
> This makes the validators suitable for automation:
> 
> ```bash
> if ./validate-tailscale-key.sh; then
>     echo "Local validation passed."
> else
>     echo "Refusing malformed credential."
>     exit 1
> fi
> ```
> 
> ## Tests
> 
> The repository includes automated tests for each implementation.
> 
> The tests deliberately use **synthetic credentials** that match the format but are not intended to be real Tailscale credentials.
> 
> Test cases include:
> 
> | Test | Expected result |
> |---|---|
> | 32-character secret | Accept |
> | 33-character secret | Accept |
> | Wrong `tskey-api-` prefix | Reject |
> | Wrong prefix capitalization | Reject |
> | 11-character identifier | Reject |
> | 13-character identifier | Reject |
> | Lowercase `cntrl` | Reject |
> | 31-character secret | Reject |
> | 34-character secret | Reject |
> | Underscore in secret | Reject |
> | Leading whitespace | Reject |
> | Trailing whitespace | Reject |
> | Empty string | Reject |
> | Arbitrary text | Reject |
> 
> ### Run Everything
> 
> From the repository root:
> 
> ```bash
> bash tests/run-all.sh
> ```
> 
> Expected output resembles:
> 
> ```text
> ==> Python tests
> ..............
> ----------------------------------------------------------------------
> Ran 14 tests
> 
> OK
> 
> ==> Node.js tests
> ✔ accepts a 32-character secret
> ✔ accepts a 33-character secret
> ...
> 
> ==> Bash tests
> PASS: 32-character secret
> PASS: 33-character secret
> ...
> 
> All validator test suites passed.
> ```
> 
> ### Python Only
> 
> ```bash
> python3 -m unittest tests/test_python.py
> ```
> 
> ### Node.js Only
> 
> ```bash
> node --test tests/test_node.js
> ```
> 
> Node's built-in test runner is used, so no test framework needs to be installed.
> 
> ### Bash Only
> 
> ```bash
> bash tests/test_bash.sh
> ```
> 
> ## CI Test Matrix
> 
> GitHub Actions automatically runs the validators across multiple supported runtimes.
> 
> | Implementation | CI environments |
> |---|---|
> | Python | Python 3.10, 3.12, 3.14 on Ubuntu |
> | Node.js | Node.js 20, 22, 24 on Ubuntu |
> | Bash | Ubuntu and macOS |
> | Dependencies | None |
> 
> CI runs automatically for pushes and pull requests.
> 
> ## Security Considerations
> 
> ### Treat Auth Keys as Secrets
> 
> Tailscale authentication keys are credentials.
> 
> Do not log them, commit them to source control, include them in bug reports, or expose them in CI output.
> 
> Bad:
> 
> ```text
> Received auth key: tskey-auth-...
> ```
> 
> Better:
> 
> ```text
> Auth key passed local structural validation.
> ```
> 
> ### Avoid Command-Line Arguments
> 
> Avoid supplying credentials directly as command-line arguments:
> 
> ```bash
> ./validator tskey-auth-...
> ```
> 
> Command-line arguments can sometimes be exposed through:
> 
> - Shell history
> - Process listings
> - Monitoring tools
> - Debugging tools
> - CI logs
> 
> Prefer an environment variable, secret manager, protected file descriptor, or hidden interactive input.
> 
> ### Do Not Automatically Repair Credentials
> 
> These validators intentionally do not:
> 
> - Trim whitespace
> - Change capitalization
> - Remove punctuation
> - Correct prefixes
> - Attempt to reconstruct truncated credentials
> 
> Credentials should be checked exactly as supplied.
> 
> For example:
> 
> ```text
>  tskey-auth-...
> ```
> 
> is rejected rather than silently converted into:
> 
> ```text
> tskey-auth-...
> ```
> 
> This makes failures explicit and avoids accidentally altering secret material.
> 
> ### Never Commit Real Test Credentials
> 
> The automated tests use synthetic strings generated solely to satisfy or violate the structural format.
> 
> Do not replace them with real auth keys.
> 
> If a real credential is accidentally committed to a Git repository, treat it as compromised and revoke it.
> 
> ## Why Use Preliminary Validation?
> 
> Local structural validation is useful anywhere a program accepts a Tailscale credential before subsequently using it for enrollment.
> 
> Examples include:
> 
> - Machine bootstrap scripts
> - Cloud-init
> - Infrastructure provisioning
> - Container entrypoints
> - CI/CD pipelines
> - Configuration-management systems
> - Web applications
> - Secret-management workflows
> - Automated installers
> - Appliance setup interfaces
> 
> It can immediately catch errors such as supplying:
> 
> ```text
> tskey-api-...
> ```
> 
> instead of:
> 
> ```text
> tskey-auth-...
> ```
> 
> or accidentally supplying a truncated credential, pasted whitespace, malformed secret, or arbitrary input.
> 
> This reduces unnecessary authentication requests and allows applications to provide useful validation errors locally.
> 
> ## Design Goals
> 
> This project intentionally stays small.
> 
> Each implementation should remain:
> 
> **Offline.** Validation must never require contacting Tailscale.
> 
> **Dependency-free.** Standard language/runtime facilities should be sufficient.
> 
> **Strict.** Malformed credentials should fail closed rather than be repaired.
> 
> **Auditable.** The validation logic should remain simple enough to inspect at a glance.
> 
> **Consistent.** Python, JavaScript, and Bash should accept and reject the same input.
> 
> ## Compatibility
> 
> This project intentionally targets the **contemporary Tailscale auth-key format**.
> 
> It does not attempt to recognize every historical Tailscale credential format.
> 
> If Tailscale changes the auth-key format in the future, the validators and corresponding test vectors will need to be updated together.
> 
> The current expressions are:
> 
> ### Python
> 
> ```python
> r"^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$"
> ```
> 
> ### JavaScript
> 
> ```javascript
> /^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$/
> ```
> 
> ### Bash
> 
> ```bash
> '^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$'
> ```
> 
> Any format change should include corresponding changes to all three implementations and their automated tests.
> 
> ## Contributing
> 
> Changes are welcome, particularly when they improve consistency or identify a change in Tailscale's contemporary credential format.
> 
> Before submitting a pull request:
> 
> ```bash
> bash tests/run-all.sh
> ```
> 
> All three validator suites should pass.
> 
> Changes to the validation rule should include new positive and negative test vectors demonstrating the intended behavior.
> 
> ## License
> 
> Add a `LICENSE` file containing the license appropriate for your project.

For the tests to import/source the real validation functions cleanly, make these small structural changes to the three validator files. They don't alter their normal CLI behavior.

**`validate_tailscale_key.py`** — put the interactive portion in `main()`:

```python
#!/usr/bin/env python3

import getpass
import re

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
```

**`validate-tailscale-key.js`** — export the function and guard the CLI:

```javascript
#!/usr/bin/env node

const TAILSCALE_AUTH_KEY_RE =
    /^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$/;

function isValidTailscaleAuthKey(key) {
    return (
        typeof key === "string" &&
        TAILSCALE_AUTH_KEY_RE.test(key)
    );
}

function main() {
    const key = process.env.TS_AUTH_KEY;

    if (!key) {
        console.error("TS_AUTH_KEY is not set.");
        return 2;
    }

    if (isValidTailscaleAuthKey(key)) {
        console.log(
            "Structurally valid contemporary Tailscale auth key."
        );
        return 0;
    }

    console.error("Invalid Tailscale auth key format.");
    return 1;
}

module.exports = {
    isValidTailscaleAuthKey,
};

if (require.main === module) {
    process.exitCode = main();
}
```

**`validate-tailscale-key.sh`** — put the executable behavior in `main` so tests can safely `source` it:

```bash
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
```

Then add the following test suite.

**`tests/test_python.py`**

```python
import unittest

from validate_tailscale_key import is_valid_tailscale_auth_key


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
```

**`tests/test_node.js`**

```javascript
const test = require("node:test");
const assert = require("node:assert/strict");

const {
    isValidTailscaleAuthKey,
} = require("../validate-tailscale-key.js");

const PREFIX = "tskey-auth-Ab12Cd34Ef56CNTRL-";
const VALID_32 = PREFIX + "A".repeat(32);
const VALID_33 = PREFIX + "B".repeat(33);

test("accepts a 32-character secret", () => {
    assert.equal(isValidTailscaleAuthKey(VALID_32), true);
});

test("accepts a 33-character secret", () => {
    assert.equal(isValidTailscaleAuthKey(VALID_33), true);
});

test("rejects API key prefix", () => {
    assert.equal(
        isValidTailscaleAuthKey(
            VALID_32.replace("tskey-auth-", "tskey-api-")
        ),
        false
    );
});

test("rejects wrong prefix capitalization", () => {
    assert.equal(
        isValidTailscaleAuthKey(
            VALID_32.replace("tskey-auth-", "TSKEY-AUTH-")
        ),
        false
    );
});

test("rejects an 11-character identifier", () => {
    const value =
        "tskey-auth-Ab12Cd34Ef5CNTRL-" + "A".repeat(32);

    assert.equal(isValidTailscaleAuthKey(value), false);
});

test("rejects a 13-character identifier", () => {
    const value =
        "tskey-auth-Ab12Cd34Ef567CNTRL-" + "A".repeat(32);

    assert.equal(isValidTailscaleAuthKey(value), false);
});

test("rejects lowercase cntrl marker", () => {
    assert.equal(
        isValidTailscaleAuthKey(
            VALID_32.replace("CNTRL", "cntrl")
        ),
        false
    );
});

test("rejects a 31-character secret", () => {
    assert.equal(
        isValidTailscaleAuthKey(PREFIX + "A".repeat(31)),
        false
    );
});

test("rejects a 34-character secret", () => {
    assert.equal(
        isValidTailscaleAuthKey(PREFIX + "A".repeat(34)),
        false
    );
});

test("rejects an underscore", () => {
    assert.equal(
        isValidTailscaleAuthKey(
            PREFIX + "A".repeat(31) + "_"
        ),
        false
    );
});

test("rejects leading whitespace", () => {
    assert.equal(
        isValidTailscaleAuthKey(" " + VALID_32),
        false
    );
});

test("rejects trailing whitespace", () => {
    assert.equal(
        isValidTailscaleAuthKey(VALID_32 + " "),
        false
    );
});

test("rejects an empty string", () => {
    assert.equal(isValidTailscaleAuthKey(""), false);
});

test("rejects arbitrary text", () => {
    assert.equal(
        isValidTailscaleAuthKey("not-a-tailscale-key"),
        false
    );
});
```

**`tests/test_bash.sh`**

```bash
#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../validate-tailscale-key.sh
source "$REPO_ROOT/validate-tailscale-key.sh"

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
```

**`tests/run-all.sh`**

```bash
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo "==> Python tests"
python3 -m unittest tests/test_python.py

echo
echo "==> Node.js tests"
node --test tests/test_node.js

echo
echo "==> Bash tests"
bash tests/test_bash.sh

echo
echo "All validator test suites passed."
```

Finally, this GitHub Actions workflow makes the CI badge functional.

**`.github/workflows/ci.yml`**

```yaml
name: CI

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  python:
    name: Python ${{ matrix.python-version }}
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        python-version:
          - "3.10"
          - "3.12"
          - "3.14"

    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}

      - name: Run Python tests
        run: python -m unittest tests/test_python.py

  node:
    name: Node.js ${{ matrix.node-version }}
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        node-version:
          - "20"
          - "22"
          - "24"

    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Run Node.js tests
        run: node --test tests/test_node.js

  bash:
    name: Bash on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}

    strategy:
      fail-fast: false
      matrix:
        os:
          - ubuntu-latest
          - macos-latest

    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Run Bash tests
        run: bash tests/test_bash.sh
```

With that layout, the project stays dependency-free while testing the actual production validation functions in **8 CI configurations**: three Python versions, three Node versions, Linux Bash, and macOS Bash.