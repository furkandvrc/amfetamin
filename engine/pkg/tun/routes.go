//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// maxRoutedAround caps host routes installed for games. P2P-heavy apps
// could otherwise make the routing table grow without bound; past the cap
// flows are simply relayed through the tunnel.
const maxRoutedAround = 512

// routeAround makes future packets to addr leave through the physical NIC
// instead of the TUN. Returns false when the flow should be relayed instead
// (cap reached, IPv6, route install failed).
func (m *Manager) routeAround(addr netip.Addr, reason string) bool {
	addr = addr.Unmap()
	if !addr.Is4() || !addr.IsGlobalUnicast() {
		return false
	}
	prefix := netip.PrefixFrom(addr, 32)

	m.routesMu.Lock()
	if _, ok := m.routedAround[prefix]; ok {
		m.routesMu.Unlock()
		return true
	}
	if len(m.routedAround) >= maxRoutedAround {
		m.routesMu.Unlock()
		return false
	}
	m.routedAround[prefix] = struct{}{}
	total := len(m.routedAround)
	m.routesMu.Unlock()

	if err := m.installRouteAround(prefix); err != nil {
		m.routesMu.Lock()
		delete(m.routedAround, prefix)
		m.routesMu.Unlock()
		m.logger.WithError(err).WithField("dst", addr.String()).Warn("could not route game server around TUN — relaying instead")
		return false
	}
	m.logger.WithField("dst", addr.String()).WithField("reason", reason).WithField("total", total).
		Info("game server routed around TUN")
	saveRouteState(m.routedAroundPrefixes())
	return true
}

func (m *Manager) routedAroundPrefixes() []netip.Prefix {
	m.routesMu.Lock()
	defer m.routesMu.Unlock()
	out := make([]netip.Prefix, 0, len(m.routedAround))
	for p := range m.routedAround {
		out = append(out, p)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Addr().Less(out[j].Addr()) })
	return out
}

// routeStatePath records host routes so `cleanup` can remove them after a
// crash (Windows routes outlive the process).
func routeStatePath() string {
	if base := os.Getenv("ProgramData"); base != "" {
		return filepath.Join(base, "amfetamin-routes")
	}
	return "/tmp/amfetamin-routes"
}

func saveRouteState(prefixes []netip.Prefix) {
	if len(prefixes) == 0 {
		os.Remove(routeStatePath())
		return
	}
	lines := make([]string, len(prefixes))
	for i, p := range prefixes {
		lines[i] = p.Addr().String()
	}
	_ = os.WriteFile(routeStatePath(), []byte(strings.Join(lines, "\n")+"\n"), 0o644)
}

// ReadRouteState returns addresses left behind by a previous run.
func ReadRouteState() []string {
	data, err := os.ReadFile(routeStatePath())
	if err != nil {
		return nil
	}
	var out []string
	for _, l := range strings.Split(string(data), "\n") {
		if l = strings.TrimSpace(l); l != "" {
			out = append(out, l)
		}
	}
	return out
}

func RemoveRouteState() { os.Remove(routeStatePath()) }
