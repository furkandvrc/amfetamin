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

func TestShouldBypassSplitTunnelHighPortUDP(t *testing.T) {
	dest := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 50001)
	if shouldBypassSplitTunnel(N.NetworkUDP, dest) {
		t.Error("UDP port >= 50000 should route through TUN, not bypass")
	}
	lowPort := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 27015)
	if !shouldBypassSplitTunnel(N.NetworkUDP, lowPort) {
		t.Error("low-port game UDP should bypass split tunnel")
	}
}
