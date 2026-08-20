//go:build (darwin || windows) && with_gvisor

package tun

import (
	"fmt"
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
	if isKnownDiscordIP(destination.Addr) {
		return true
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

func splitTunnelBypassReason(network string, destination M.Socksaddr) (bypass bool, reason string) {
	if !destination.IsValid() {
		return false, "invalid"
	}

	addr := destination.Addr
	if !addr.IsGlobalUnicast() || addr.IsPrivate() || addr.IsLoopback() || addr.IsLinkLocalUnicast() {
		return true, "lan"
	}

	if network == N.NetworkUDP {
		if isGameUDPBypassPort(destination.Port) {
			return true, fmt.Sprintf("game-udp:%d", destination.Port)
		}
		return false, "discord-or-other-udp"
	}

	if network == N.NetworkTCP {
		if destination.Port == 443 {
			return false, "https"
		}
		if isGameTCPBypassPort(destination.Port) {
			return true, fmt.Sprintf("game-tcp:%d", destination.Port)
		}
		if isDiscordDestination(destination) {
			return false, "discord-tcp"
		}
		return true, fmt.Sprintf("tcp:%d", destination.Port)
	}

	return false, "default-tun"
}

func shouldBypassSplitTunnel(network string, destination M.Socksaddr) bool {
	bypass, _ := splitTunnelBypassReason(network, destination)
	return bypass
}
