//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"

	M "github.com/sagernet/sing/common/metadata"
)

func tunnelBypassReason(network string, destination M.Socksaddr) (bypass bool, reason string) {
	if !destination.IsValid() {
		return false, "invalid"
	}

	addr := destination.Addr
	if addr.IsMulticast() || addr.IsPrivate() || addr.IsLoopback() || addr.IsLinkLocalUnicast() {
		return true, "local"
	}
	if !addr.IsGlobalUnicast() {
		return true, "non-global"
	}

	if ok, label := matchConfiguredBypass(network, destination.Port); ok {
		return true, "rule:" + label
	}

	return false, "tun"
}

func shouldBypassTunnel(network string, destination M.Socksaddr) bool {
	bypass, _ := tunnelBypassReason(network, destination)
	return bypass
}

// splitTunnelRouteExcludes kept for legacy --split-tunnel flag (LAN only).
var splitTunnelRouteExcludes = []netip.Prefix{
	netip.MustParsePrefix("10.0.0.0/8"),
	netip.MustParsePrefix("172.16.0.0/12"),
	netip.MustParsePrefix("192.168.0.0/16"),
	netip.MustParsePrefix("127.0.0.0/8"),
	netip.MustParsePrefix("169.254.0.0/16"),
	netip.MustParsePrefix("224.0.0.0/4"),
}
