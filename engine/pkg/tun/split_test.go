//go:build (darwin || windows) && with_gvisor

package tun

import "testing"

func TestIsDiscordHost(t *testing.T) {
	cases := map[string]bool{
		"discord.com":              true,
		"gateway.discord.gg":       true,
		"rome7098.discord.media":   true,
		"cdn.discordapp.com":       true,
		"google.com":               false,
		"riotgames.com":            false,
	}
	for host, want := range cases {
		if got := isDiscordHost(host); got != want {
			t.Errorf("isDiscordHost(%q) = %v, want %v", host, got, want)
		}
	}
}
