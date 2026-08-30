//go:build darwin && with_gvisor

package tun

import "net/netip"

func (m *Manager) applyGameRouteExclude(prefix netip.Prefix) error {
	if m.tunDevice == nil {
		return nil
	}
	return m.tunDevice.UpdateRouteOptions(m.tunOptions())
}

func (m *Manager) removeGameRouteExclude(netip.Prefix) {}

func (m *Manager) cleanupGameRouteExcludes() {}
