//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"
	"testing"

	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
)

func TestIsDiscordHost(t *testing.T) {
	cases := map[string]bool{
		"discord.com":            true,
		"gateway.discord.gg":     true,
		"rome7098.discord.media": true,
		"cdn.discordapp.com":     true,
		"google.com":             false,
		"riotgames.com":          false,
	}
	for host, want := range cases {
		if got := isDiscordHost(host); got != want {
			t.Errorf("isDiscordHost(%q) = %v, want %v", host, got, want)
		}
	}
}

func TestShouldBypassTunnelConfiguredRules(t *testing.T) {
	SetBypassRules([]string{"udp:4950-4955", "tcp:6695-6699"})

	wf := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 4950)
	if !shouldBypassTunnel(N.NetworkUDP, wf) {
		t.Error("configured warframe UDP should bypass")
	}
	wfTCP := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 6697)
	if !shouldBypassTunnel(N.NetworkTCP, wfTCP) {
		t.Error("configured warframe TCP should bypass")
	}

	discord := M.SocksaddrFrom(netip.MustParseAddr("104.29.142.99"), 19327)
	if shouldBypassTunnel(N.NetworkUDP, discord) {
		t.Error("discord voice UDP should use full TUN")
	}
}
