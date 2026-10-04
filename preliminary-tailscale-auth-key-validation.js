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