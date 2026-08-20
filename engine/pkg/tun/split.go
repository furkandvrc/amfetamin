//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"
	"strings"

	gecitdns "github.com/boratanrikulu/gecit/pkg/dns"
	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
)

var splitTunnelRouteExcludes = []netip.Prefix{
	netip.MustParsePrefix("10.0.0.0/8"),
	netip.MustParsePrefix("172.16.0.0/12"),
	netip.MustParsePrefix("192.168.0.0/16"),
	netip.MustParsePrefix("127.0.0.0/8"),
	netip.MustParsePrefix("169.254.0.0/16"),
	netip.MustParsePrefix("224.0.0.0/4"),
}

func isDiscordHost(domain string) bool {
	domain = strings.ToLower(strings.TrimSuffix(domain, "."))
	switch domain {
	case "discord.com", "discord.gg", "discord.media", "discordapp.com", "discordapp.net":
		return true
	}
	suffixes := []string{
		".discord.com",
		".discord.gg",
		".discord.media",
		".discordapp.com",
		".discordapp.net",
		".discordcdn.com",
	}
	for _, sfx := range suffixes {
		if strings.HasSuffix(domain, sfx) {
			return true
		}
	}
	return false
}

func isDiscordDestination(destination M.Socksaddr) bool {
	if !destination.IsValid() {
		return false
	}
	if dns := gecitdns.GetDNSServer(); dns != nil {
		for _, domain := range dns.DomainsForIP(destination.Addr.String()) {
			if isDiscordHost(domain) {
				return true
			}
		}
	}
	return false
}

func shouldBypassSplitTunnel(network string, destination M.Socksaddr) bool {
	if !destination.IsValid() {
		return false
	}

	addr := destination.Addr
	if !addr.IsGlobalUnicast() || addr.IsPrivate() || addr.IsLoopback() || addr.IsLinkLocalUnicast() {
		return true
	}

	if network == N.NetworkUDP {
		// Discord voice uses high UDP ports; DNS cache may miss media IPs.
		if isDiscordDestination(destination) || destination.Port >= 50000 {
			return false
		}
		return true
	}

	if network == N.NetworkTCP && destination.Port != 443 {
		return true
	}

	return false
}
