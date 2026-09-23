//go:build windows && with_gvisor

package tun

import (
	"fmt"
	"net/netip"
	"os/exec"
	"strconv"
	"strings"
	"syscall"

	"github.com/boratanrikulu/gecit/pkg/netif"
)

func hiddenCmd(name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	return cmd
}

func (m *Manager) installRouteAround(prefix netip.Prefix) error {
	gw := m.phys.Gateway
	if gw == nil {
		gw = netif.GatewayFor(m.phys.IP)
	}
	if gw == nil {
		return fmt.Errorf("physical gateway not found")
	}
	args := []string{"add", prefix.Addr().String(), "mask", "255.255.255.255", gw.String(), "metric", "1"}
	if m.phys.Index > 0 {
		args = append(args, "IF", strconv.Itoa(m.phys.Index))
	}
	// `route add` fails on an existing route and its message is localized,
	// so make the add idempotent instead of parsing the error text.
	DeleteHostRoute(prefix.Addr().String())
	out, err := hiddenCmd("route", args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("route add %s: %w (%s)", prefix.Addr(), err, strings.TrimSpace(string(out)))
	}
	return nil
}

func (m *Manager) cleanupRoutesAround() {
	for _, p := range m.routedAroundPrefixes() {
		DeleteHostRoute(p.Addr().String())
	}
	RemoveRouteState()
}

// DeleteHostRoute removes a /32 route added by routeAround.
func DeleteHostRoute(ip string) {
	_ = hiddenCmd("route", "delete", ip, "mask", "255.255.255.255").Run()
}
