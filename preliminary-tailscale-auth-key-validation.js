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