//go:build (darwin || windows) && with_gvisor

package tun

import (
	"strings"

	gecitdns "github.com/boratanrikulu/gecit/pkg/dns"
	M "github.com/sagernet/sing/common/metadata"
)

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
