//go:build (darwin || windows) && with_gvisor

package tun

import (
	"context"
	"net"
	"net/netip"
	"sort"
	"time"
)

var discordPrefetchDomains = []string{
	"discord.com",
	"discord.gg",
	"discordapp.com",
	"discordapp.net",
	"discord.media",
	"cdn.discordapp.com",
	"gateway.discord.gg",
	"status.discord.com",
}

func (m *Manager) gameBypassMode() bool {
	return len(m.cfg.BypassRules) > 0
}

func (m *Manager) prefetchDiscordRoutes(ctx context.Context) {
	for _, domain := range discordPrefetchDomains {
		select {
		case <-ctx.Done():
			return
		default:
		}
		ips, err := net.DefaultResolver.LookupIP(ctx, "ip4", domain)
		if err != nil {
			m.logger.WithError(err).WithField("domain", domain).Debug("discord prefetch lookup failed")
			continue
		}
		addrs := make([]netip.Addr, 0, len(ips))
		for _, ip := range ips {
			if addr, ok := netip.AddrFromSlice(ip.To4()); ok && addr.IsValid() {
				addrs = append(addrs, addr)
			}
		}
		if len(addrs) > 0 {
			m.addDiscordRoutes(addrs, "prefetch:"+domain)
		}
	}
}

func (m *Manager) AddDiscordRoutes(ips []string) {
	addrs := make([]netip.Addr, 0, len(ips))
	for _, ip := range ips {
		if addr, err := netip.ParseAddr(ip); err == nil && addr.Is4() {
			addrs = append(addrs, addr)
		}
	}
	if len(addrs) > 0 {
		m.addDiscordRoutes(addrs, "dns")
	}
}

func (m *Manager) addDiscordRoutes(addrs []netip.Addr, reason string) {
	if !m.gameBypassMode() || len(addrs) == 0 {
		return
	}

	m.discordRoutesMu.Lock()
	added := make([]netip.Addr, 0, len(addrs))
	for _, addr := range addrs {
		if !addr.IsValid() || !addr.Is4() || !addr.IsGlobalUnicast() {
			continue
		}
		prefix := netip.PrefixFrom(addr, 32)
		if _, ok := m.discordRoutes[prefix]; ok {
			continue
		}
		m.discordRoutes[prefix] = struct{}{}
		added = append(added, addr)
	}
	m.discordRoutesMu.Unlock()

	if len(added) == 0 {
		return
	}

	m.logger.WithFields(map[string]interface{}{
		"ips":    added,
		"reason": reason,
		"total":  len(m.discordRoutePrefixes()),
	}).Info("discord route added")

	if err := m.refreshTunRoutes(); err != nil {
		m.logger.WithError(err).Warn("failed to update TUN routes")
	}
}

func (m *Manager) noteDiscordRoute(addr netip.Addr) {
	if !m.gameBypassMode() || !addr.IsValid() {
		return
	}
	m.addDiscordRoutes([]netip.Addr{addr}, "traffic")
}

func (m *Manager) discordRoutePrefixes() []netip.Prefix {
	m.discordRoutesMu.Lock()
	defer m.discordRoutesMu.Unlock()
	out := make([]netip.Prefix, 0, len(m.discordRoutes))
	for prefix := range m.discordRoutes {
		out = append(out, prefix)
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].String() < out[j].String()
	})
	return out
}

func (m *Manager) refreshTunRoutes() error {
	if m.tunDevice == nil || !m.gameBypassMode() {
		return nil
	}
	opts := m.tunOptions()
	return m.tunDevice.UpdateRouteOptions(opts)
}

func (m *Manager) warmDiscordRoutesBeforeTUN(ctx context.Context) {
	prefetchCtx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	m.prefetchDiscordRoutes(prefetchCtx)
}
