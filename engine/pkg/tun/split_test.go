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

func TestShouldBypassTunnelWarframe(t *testing.T) {
	wfUDP := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 4950)
	if !shouldBypassTunnel(N.NetworkUDP, wfUDP) {
		t.Error("Warframe UDP 4950 should bypass TUN")
	}
	wfTCP := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 6697)
	if !shouldBypassTunnel(N.NetworkTCP, wfTCP) {
		t.Error("Warframe TCP 6697 should bypass TUN")
	}
}

func TestShouldBypassTunnelFullTunnel(t *testing.T) {
	discordVoice := M.SocksaddrFrom(netip.MustParseAddr("104.29.142.99"), 19327)
	if shouldBypassTunnel(N.NetworkUDP, discordVoice) {
		t.Error("Discord voice UDP should use full TUN, not bypass")
	}
	riotUDP := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 5223)
	if shouldBypassTunnel(N.NetworkUDP, riotUDP) {
		t.Error("LoL/other game UDP should use full TUN")
	}
	https := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 443)
	if shouldBypassTunnel(N.NetworkTCP, https) {
		t.Error("HTTPS should use TUN")
	}
}

func TestIsWarframeBypassPort(t *testing.T) {
	if !isWarframeBypassPort(N.NetworkUDP, 4950) || !isWarframeBypassPort(N.NetworkUDP, 4955) {
		t.Error("Warframe default UDP ports")
	}
	if !isWarframeBypassPort(N.NetworkTCP, 6695) {
		t.Error("Warframe TCP range")
	}
	if isWarframeBypassPort(N.NetworkUDP, 27015) {
		t.Error("Steam ports should not bypass")
	}
}
