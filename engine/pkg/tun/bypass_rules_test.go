//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"
	"testing"

	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
)

func addr(ip string, port uint16) M.Socksaddr {
	return M.SocksaddrFrom(netip.MustParseAddr(ip), port)
}

func TestIsDiscordHost(t *testing.T) {
	cases := map[string]bool{
		"discord.com":            true,
		"gateway.discord.gg":     true,
		"rome7098.discord.media": true,
		"cdn.discordapp.com":     true,
		"notdiscord.com":         false,
		"google.com":             false,
	}
	for host, want := range cases {
		if got := isDiscordHost(host); got != want {
			t.Errorf("isDiscordHost(%q) = %v, want %v", host, got, want)
		}
	}
}

func TestClassifyFlowPortRules(t *testing.T) {
	SetBypassRules([]string{"udp:4950-4955", "tcp:6695-6699", "27015"})
	defer SetBypassRules(nil)

	cases := []struct {
		name    string
		network string
		src     M.Socksaddr
		dst     M.Socksaddr
		want    bypassDecision
	}{
		{"warframe dst udp", N.NetworkUDP, M.Socksaddr{}, addr("203.0.113.1", 4950), routeAround},
		{"warframe udp rule is udp only", N.NetworkTCP, M.Socksaddr{}, addr("203.0.113.1", 4950), viaTunnel},
		{"warframe dst tcp", N.NetworkTCP, M.Socksaddr{}, addr("203.0.113.1", 6697), relayDirect},
		{"game src port", N.NetworkUDP, addr("10.0.85.1", 4955), addr("203.0.113.50", 7777), routeAround},
		{"both protocols udp", N.NetworkUDP, M.Socksaddr{}, addr("203.0.113.1", 27015), routeAround},
		{"both protocols tcp", N.NetworkTCP, M.Socksaddr{}, addr("203.0.113.1", 27015), relayDirect},
		{"lan", N.NetworkUDP, M.Socksaddr{}, addr("192.168.1.10", 1900), relayDirect},
		{"https", N.NetworkTCP, M.Socksaddr{}, addr("162.159.135.232", 443), viaTunnel},
		{"discord voice", N.NetworkUDP, M.Socksaddr{}, addr("104.29.142.99", 19327), viaTunnel},
	}
	for _, c := range cases {
		if got, reason := classifyFlow(c.network, c.src, c.dst); got != c.want {
			t.Errorf("%s: got %v (%s), want %v", c.name, got, reason, c.want)
		}
	}
}

func TestClassifyFlowAutoUDP(t *testing.T) {
	SetBypassRules([]string{AutoUDPSpec})
	defer SetBypassRules(nil)

	if got, _ := classifyFlow(N.NetworkUDP, addr("10.0.85.1", 50000), addr("203.0.113.9", 7777)); got != routeAround {
		t.Errorf("game UDP should be routed around, got %v", got)
	}
	if got, _ := classifyFlow(N.NetworkUDP, addr("10.0.85.1", 50000), addr("203.0.113.9", 443)); got != viaTunnel {
		t.Errorf("QUIC must stay in the tunnel, got %v", got)
	}
	if got, _ := classifyFlow(N.NetworkUDP, addr("10.0.85.1", 50000), addr("66.22.200.10", 50003)); got != viaTunnel {
		t.Errorf("Discord voice must stay in the tunnel, got %v", got)
	}
	if got, _ := classifyFlow(N.NetworkTCP, addr("10.0.85.1", 50000), addr("203.0.113.9", 7777)); got != viaTunnel {
		t.Errorf("auto mode is UDP only, got %v", got)
	}
}

func TestParseBypassRuleSpecErrors(t *testing.T) {
	for _, spec := range []string{"", "foo:1", "udp:0", "udp:10-5", "tcp:70000"} {
		if _, err := parseBypassRuleSpec(spec); err == nil {
			t.Errorf("expected error for %q", spec)
		}
	}
	if errs := SetBypassRules([]string{"udp:1-2", "bad"}); len(errs) != 1 {
		t.Errorf("expected one error, got %v", errs)
	}
	SetBypassRules(nil)
}
