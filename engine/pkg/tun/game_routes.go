//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"
	"sort"

	M "github.com/sagernet/sing/common/metadata"
)

func gameSourcePortBypass(network string, source M.Socksaddr) (bool, string) {
	if !source.IsValid() || source.Port == 0 {
		return false, ""
	}
	return matchConfiguredBypass(network, source.Port)
}

func (m *Manager) excludeGameDestFromTUN(addr netip.Addr, reason string) {
	if !m.gameBypassMode() || !addr.IsValid() || !addr.Is4() || !addr.IsGlobalUnicast() {
		return
	}
	prefix := netip.PrefixFrom(addr, 32)

	m.gameRouteExcludesMu.Lock()
	if _, ok := m.gameRouteExcludes[prefix]; ok {
		m.gameRouteExcludesMu.Unlock()
		return
	}
	m.gameRouteExcludes[prefix] = struct{}{}
	total := len(m.gameRouteExcludes)
	m.gameRouteExcludesMu.Unlock()

	m.logger.WithFields(map[string]interface{}{
		"prefix": prefix.String(),
		"reason": reason,
		"total":  total,
	}).Info("game server excluded from TUN")

	if err := m.applyGameRouteExclude(prefix); err != nil {
		m.logger.WithError(err).WithField("prefix", prefix.String()).Warn("failed to add physical bypass route")
	}
}

func (m *Manager) gameRouteExcludePrefixes() []netip.Prefix {
	m.gameRouteExcludesMu.Lock()
	defer m.gameRouteExcludesMu.Unlock()
	out := make([]netip.Prefix, 0, len(m.gameRouteExcludes))
	for prefix := range m.gameRouteExcludes {
		out = append(out, prefix)
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].String() < out[j].String()
	})
	return out
}

func (m *Manager) routeExcludePrefixes() []netip.Prefix {
	if m.gameBypassMode() || m.cfg.SplitTunnel {
		return append([]netip.Prefix(nil), splitTunnelRouteExcludes...)
	}
	return nil
}
