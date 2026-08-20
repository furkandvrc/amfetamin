//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"
	"testing"

	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
)

func TestParseBypassRuleSpec(t *testing.T) {
	SetBypassRules([]string{
		"udp:4950-4955",
		"tcp:6695-6699",
		"27015",
	})

	wf := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 4950)
	if !shouldBypassTunnel(N.NetworkUDP, M.Socksaddr{}, wf) {
		t.Fatal("warframe udp should bypass")
	}
	if shouldBypassTunnel(N.NetworkTCP, M.Socksaddr{}, wf) {
		t.Fatal("4950 tcp not in tcp-only warframe udp rule alone - but 4950-4955 includes tcp:4950-4955")
	}

	// Warframe sends from local UDP 4950/4955 to arbitrary server ports.
	wfSrc := M.SocksaddrFrom(netip.MustParseAddr("10.0.0.5"), 4950)
	wfDst := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.50"), 6112)
	if !shouldBypassTunnel(N.NetworkUDP, wfSrc, wfDst) {
		t.Fatal("warframe egress udp should bypass by source port")
	}

	rust := M.SocksaddrFrom(netip.MustParseAddr("203.0.113.1"), 27015)
	if !shouldBypassTunnel(N.NetworkUDP, M.Socksaddr{}, rust) {
		t.Fatal("27015 both protocols")
	}
	if !shouldBypassTunnel(N.NetworkTCP, M.Socksaddr{}, rust) {
		t.Fatal("27015 both protocols tcp")
	}

	discord := M.SocksaddrFrom(netip.MustParseAddr("104.29.142.99"), 19327)
	if shouldBypassTunnel(N.NetworkUDP, M.Socksaddr{}, discord) {
		t.Fatal("discord voice should use TUN")
	}
}

func TestParseBypassRuleSpecErrors(t *testing.T) {
	if _, err := parseBypassRuleSpec(""); err == nil {
		t.Fatal("expected error for empty")
	}
	if _, err := parseBypassRuleSpec("foo:1"); err == nil {
		t.Fatal("expected error for bad proto")
	}
}
