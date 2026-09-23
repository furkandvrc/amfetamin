//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"

	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
)

// bypassDecision says how a flow entering the TUN should be handled.
type bypassDecision int

const (
	// viaTunnel: normal path — proxied through the physical NIC, with fake
	// ClientHello injection on target ports.
	viaTunnel bypassDecision = iota
	// relayDirect: relay without injection (LAN, configured destination ports).
	relayDirect
	// routeAround: install a host route so the flow's destination leaves the
	// TUN entirely; the current flow is dropped and the app's retry goes
	// straight out of the physical NIC (games, anti-cheat friendly).
	routeAround
)

// webUDPPorts must stay inside the tunnel even in auto mode: DNS, HTTP/3
// (QUIC) and DoT carry hostnames the DPI inspects.
var webUDPPorts = map[uint16]bool{53: true, 80: true, 443: true, 853: true}

func classifyFlow(network string, source, destination M.Socksaddr) (bypassDecision, string) {
	d, reason := classify(network, source, destination)
	// Discord must stay reachable through the tunnel no matter which port
	// rules the user configured.
	if d == routeAround && isDiscordDestination(destination) {
		return viaTunnel, reason + "+discord"
	}
	return d, reason
}

func classify(network string, source, destination M.Socksaddr) (bypassDecision, string) {
	if !destination.IsValid() {
		return viaTunnel, "invalid"
	}

	addr := destination.Addr
	if addr.IsMulticast() || addr.IsPrivate() || addr.IsLoopback() || addr.IsLinkLocalUnicast() {
		return relayDirect, "local"
	}
	if !addr.IsGlobalUnicast() {
		return relayDirect, "non-global"
	}

	// Game clients send from fixed local ports to arbitrary server ports —
	// route those servers around the TUN.
	if source.IsValid() && source.Port != 0 {
		if ok, label := matchConfiguredBypass(network, source.Port); ok {
			return routeAround, "rule:src:" + label
		}
	}
	if ok, label := matchConfiguredBypass(network, destination.Port); ok {
		// UDP game traffic gains nothing from the tunnel (no TLS to
		// disguise), so take it out of the userspace stack entirely.
		if network == N.NetworkUDP {
			return routeAround, "rule:dst:" + label
		}
		return relayDirect, "rule:dst:" + label
	}

	if network == N.NetworkUDP && currentRules().autoUDP && !webUDPPorts[destination.Port] && !discordRTCPort(destination.Port) {
		return routeAround, "auto-udp"
	}
	return viaTunnel, "tun"
}

// shouldBypassTunnel reports whether a flow skips fake injection.
// discordRTCPort is a safety net for Discord voice servers that were never
// seen in DNS (the app caches them): their RTC ports stay in the tunnel.
func discordRTCPort(port uint16) bool {
	return (port >= 19294 && port <= 19344) || (port >= 50000 && port <= 50100)
}

func shouldBypassTunnel(network string, source, destination M.Socksaddr) bool {
	d, _ := classifyFlow(network, source, destination)
	return d != viaTunnel
}

// lanRouteExcludes keep LAN/multicast off the TUN when games are configured
// (UPnP, LAN discovery, local game servers).
var lanRouteExcludes = []netip.Prefix{
	netip.MustParsePrefix("10.0.0.0/8"),
	netip.MustParsePrefix("172.16.0.0/12"),
	netip.MustParsePrefix("192.168.0.0/16"),
	netip.MustParsePrefix("100.64.0.0/10"),
	netip.MustParsePrefix("127.0.0.0/8"),
	netip.MustParsePrefix("169.254.0.0/16"),
	netip.MustParsePrefix("224.0.0.0/4"),
}
