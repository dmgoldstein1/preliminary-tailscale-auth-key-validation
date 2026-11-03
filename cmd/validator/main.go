package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strings"
)

var tailscaleAuthKeyRegexp = regexp.MustCompile(`^tskey-auth-[A-Za-z0-9]{12}CNTRL-[A-Za-z0-9]{32,33}$`)

func IsValidTailscaleAuthKey(key string) bool {
	return tailscaleAuthKeyRegexp.MatchString(key)
}

func main() {
	var key string
	if envKey, ok := os.LookupEnv("TS_AUTH_KEY"); ok && envKey != "" {
		key = envKey
	} else {
		reader := bufio.NewReader(os.Stdin)
		input, err := reader.ReadString('\n')
		key = strings.TrimRight(input, "\r\n")
		if key == "" {
			// No env var and no meaningful stdin — match exit code 2 convention
			// for missing input, but treat an explicit empty line / EOF as
			// invalid format (exit 1) when we actually read something,
			// and missing when we read nothing.
			if err != nil {
				fmt.Fprintln(os.Stderr, "No input provided.")
				os.Exit(2)
			}
		}
	}

	if IsValidTailscaleAuthKey(key) {
		fmt.Println("Structurally valid contemporary Tailscale auth key.")
		os.Exit(0)
	}

	fmt.Fprintln(os.Stderr, "Invalid Tailscale auth key format.")
	os.Exit(1)
}
