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

func TestShouldBypassSplitTunnelUDP(t *testing.T) {
	game := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 27015)
	if !shouldBypassSplitTunnel(N.NetworkUDP, game) {
		t.Error("game UDP should bypass split tunnel")
	}

	voice := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 50001)
	if shouldBypassSplitTunnel(N.NetworkUDP, voice) {
		t.Error("discord voice UDP should route through TUN (ISP blocks direct UDP)")
	}
}

func TestShouldBypassSplitTunnelTCP(t *testing.T) {
	https := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 443)
	if shouldBypassSplitTunnel(N.NetworkTCP, https) {
		t.Error("HTTPS should use TUN")
	}

	warframe := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 4952)
	if !shouldBypassSplitTunnel(N.NetworkTCP, warframe) {
		t.Error("Warframe UPnP TCP should bypass")
	}

	noteDiscordIP(netip.MustParseAddr("203.0.113.50"))
	discordTCP := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.50"), 8443)
	if shouldBypassSplitTunnel(N.NetworkTCP, discordTCP) {
		t.Error("known Discord IP TCP should use TUN")
	}
}

func TestIsGameUDPBypassPort(t *testing.T) {
	if !isGameUDPBypassPort(27015) || !isGameUDPBypassPort(28015) || !isGameUDPBypassPort(5200) {
		t.Error("expected game UDP ports to bypass")
	}
	if isGameUDPBypassPort(50001) {
		t.Error("discord voice ports should not be in game bypass list")
	}
}
