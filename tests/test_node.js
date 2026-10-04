const test = require("node:test");
const assert = require("node:assert/strict");

const {
    isValidTailscaleAuthKey,
} = require("../preliminary-tailscale-auth-key-validation.js");

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
