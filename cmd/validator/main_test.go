package main

import (
	"strings"
	"testing"
)

const prefix = "tskey-auth-Ab12Cd34Ef56CNTRL-"

var (
	valid32 = prefix + strings.Repeat("A", 32)
	valid33 = prefix + strings.Repeat("B", 33)
)

func TestIsValidTailscaleAuthKey(t *testing.T) {
	tests := []struct {
		name  string
		value string
		want  bool
	}{
		{"accepts 32-character secret", valid32, true},
		{"accepts 33-character secret", valid33, true},
		{"rejects API key prefix", strings.Replace(valid32, "tskey-auth-", "tskey-api-", 1), false},
		{"rejects wrong prefix capitalization", strings.Replace(valid32, "tskey-auth-", "TSKEY-AUTH-", 1), false},
		{"rejects 11-character identifier", "tskey-auth-Ab12Cd34Ef5CNTRL-" + strings.Repeat("A", 32), false},
		{"rejects 13-character identifier", "tskey-auth-Ab12Cd34Ef567CNTRL-" + strings.Repeat("A", 32), false},
		{"rejects lowercase cntrl marker", strings.Replace(valid32, "CNTRL", "cntrl", 1), false},
		{"rejects 31-character secret", prefix + strings.Repeat("A", 31), false},
		{"rejects 34-character secret", prefix + strings.Repeat("A", 34), false},
		{"rejects underscore in secret", prefix + strings.Repeat("A", 31) + "_", false},
		{"rejects leading whitespace", " " + valid32, false},
		{"rejects trailing whitespace", valid32 + " ", false},
		{"rejects empty string", "", false},
		{"rejects arbitrary text", "not-a-tailscale-key", false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := IsValidTailscaleAuthKey(tc.value); got != tc.want {
				t.Errorf("IsValidTailscaleAuthKey(%q) = %v, want %v", tc.value, got, tc.want)
			}
		})
	}
}
