//go:build (darwin || windows) && with_gvisor

package tun

import (
	"net/netip"
	"sync"
	"time"
)

const discordIPCacheTTL = 2 * time.Hour

var (
	discordIPMu sync.Mutex
	discordIPs  = map[netip.Addr]time.Time{}
)

func noteDiscordIP(addr netip.Addr) {
	if !addr.IsValid() || !addr.IsGlobalUnicast() {
		return
	}
	discordIPMu.Lock()
	discordIPs[addr] = time.Now().Add(discordIPCacheTTL)
	discordIPMu.Unlock()

	if mgr := globalDiscordRouteMgr; mgr != nil {
		mgr.noteDiscordRoute(addr)
	}
}

var globalDiscordRouteMgr *Manager

func registerDiscordRouteManager(m *Manager) {
	globalDiscordRouteMgr = m
}

func unregisterDiscordRouteManager(m *Manager) {
	if globalDiscordRouteMgr == m {
		globalDiscordRouteMgr = nil
	}
}

func isKnownDiscordIP(addr netip.Addr) bool {
	if !addr.IsValid() {
		return false
	}
	now := time.Now()
	discordIPMu.Lock()
	defer discordIPMu.Unlock()
	exp, ok := discordIPs[addr]
	if !ok {
		return false
	}
	if now.After(exp) {
		delete(discordIPs, addr)
		return false
	}
	return true
}
