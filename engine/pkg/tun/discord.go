//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"
	"strings"
	"sync"
	"time"

	gecitdns "github.com/boratanrikulu/gecit/pkg/dns"
	M "github.com/sagernet/sing/common/metadata"
)

// Discord voice/RTC must stay inside the tunnel on blocked networks, so the
// engine remembers which IPs belong to Discord (from DNS answers and SNI) and
// never routes them around the TUN.

const discordIPTTL = 2 * time.Hour

var discordSuffixes = []string{
	"discord.com", "discord.gg", "discord.media", "discordapp.com",
	"discordapp.net", "discordcdn.com", "discord.dev", "discord.new",
}

func IsDiscordHost(domain string) bool { return isDiscordHost(domain) }

func isDiscordHost(domain string) bool {
	domain = strings.ToLower(strings.TrimSuffix(domain, "."))
	for _, sfx := range discordSuffixes {
		if domain == sfx || strings.HasSuffix(domain, "."+sfx) {
			return true
		}
	}
	return false
}

var discordIPs = struct {
	sync.Mutex
	m         map[netip.Addr]time.Time
	lastPrune time.Time
}{m: make(map[netip.Addr]time.Time)}

func noteDiscordIP(addr netip.Addr) {
	if !addr.IsValid() || !addr.IsGlobalUnicast() {
		return
	}
	now := time.Now()
	discordIPs.Lock()
	defer discordIPs.Unlock()
	discordIPs.m[addr.Unmap()] = now.Add(discordIPTTL)
	if now.Sub(discordIPs.lastPrune) > 10*time.Minute {
		discordIPs.lastPrune = now
		for a, exp := range discordIPs.m {
			if now.After(exp) {
				delete(discordIPs.m, a)
			}
		}
	}
}

func isKnownDiscordIP(addr netip.Addr) bool {
	if !addr.IsValid() {
		return false
	}
	discordIPs.Lock()
	defer discordIPs.Unlock()
	exp, ok := discordIPs.m[addr.Unmap()]
	return ok && time.Now().Before(exp)
}

// discordPrefixes are Discord-owned ranges (AS49544). Voice servers are
// handed to the client as raw IPs over the voice gateway, so they are not
// always visible in DNS answers.
var discordPrefixes = []netip.Prefix{
	netip.MustParsePrefix("66.22.192.0/18"),
}

func isDiscordDestination(destination M.Socksaddr) bool {
	if !destination.IsValid() {
		return false
	}
	for _, p := range discordPrefixes {
		if p.Contains(destination.Addr.Unmap()) {
			return true
		}
	}
	if isKnownDiscordIP(destination.Addr) {
		return true
	}
	if dns := gecitdns.GetDNSServer(); dns != nil {
		for _, domain := range dns.DomainsForIP(destination.Addr.Unmap().String()) {
			if isDiscordHost(domain) {
				noteDiscordIP(destination.Addr)
				return true
			}
		}
	}
	return false
}
