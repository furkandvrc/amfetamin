//go:build (darwin || windows) && with_gvisor

package tun

import N "github.com/sagernet/sing/common/network"

// Warframe network ports (https://www.warframe.com/en/portinuse, wiki Network Architecture).
// Bypass TUN so UPnP/matchmaking work; everything else uses full tunnel like pre-split builds.
func isWarframeBypassPort(network string, port uint16) bool {
	if port >= 4950 && port <= 4955 {
		return true // default UDP + UPnP/NAT-PMP range (PC options may change ports within this span)
	}
	if network == N.NetworkTCP && port >= 6695 && port <= 6699 {
		return true // Warframe TCP game ports
	}
	return false
}
