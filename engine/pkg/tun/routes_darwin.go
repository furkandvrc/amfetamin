//go:build darwin && with_gvisor

package tun

import (
	"net/netip"
	"time"
)

// On macOS sing-tun installs the TUN routes as a set of prefixes, so routing
// a host around the TUN means rebuilding that set without it. Rebuilding
// briefly removes every TUN route, so updates are coalesced.
func (m *Manager) installRouteAround(netip.Prefix) error {
	m.routesMu.Lock()
	if m.routeUpdate == nil {
		m.routeUpdate = time.AfterFunc(150*time.Millisecond, m.applyTunRoutes)
	} else {
		m.routeUpdate.Reset(150 * time.Millisecond)
	}
	m.routesMu.Unlock()
	return nil
}

func (m *Manager) applyTunRoutes() {
	if m.tunDevice == nil {
		return
	}
	if err := m.tunDevice.UpdateRouteOptions(m.tunOptions()); err != nil {
		m.logger.WithError(err).Warn("failed to update TUN routes")
	}
}

// Routes vanish with the utun device; nothing to clean up.
func (m *Manager) cleanupRoutesAround() { RemoveRouteState() }

func DeleteHostRoute(string) {}
