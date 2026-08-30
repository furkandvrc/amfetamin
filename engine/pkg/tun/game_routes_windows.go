//go:build windows && with_gvisor

package tun

import (
	"fmt"
	"net/netip"
	"os/exec"
	"strings"
)

func (m *Manager) applyGameRouteExclude(prefix netip.Prefix) error {
	if !prefix.IsValid() || !prefix.Addr().Is4() {
		return fmt.Errorf("invalid prefix")
	}
	gw, err := m.physicalGateway()
	if err != nil {
		return err
	}
	dest := prefix.Addr().String()
	out, err := exec.Command("route", "add", dest, "mask", "255.255.255.255", gw, "metric", "1").CombinedOutput()
	if err != nil {
		text := strings.ToLower(string(out))
		if strings.Contains(text, "already exists") || strings.Contains(text, "object already exists") {
			return nil
		}
		return fmt.Errorf("route add %s: %w (%s)", dest, err, strings.TrimSpace(string(out)))
	}
	return nil
}

func (m *Manager) removeGameRouteExclude(prefix netip.Prefix) {
	if !prefix.IsValid() || !prefix.Addr().Is4() {
		return
	}
	dest := prefix.Addr().String()
	exec.Command("route", "delete", dest).Run()
}

func (m *Manager) physicalGateway() (string, error) {
	out, err := exec.Command("cmd", "/c", "route", "print", "0.0.0.0").CombinedOutput()
	if err != nil {
		return "", err
	}
	for _, line := range strings.Split(string(out), "\n") {
		fields := strings.Fields(strings.TrimSpace(line))
		if len(fields) >= 3 && fields[0] == "0.0.0.0" && fields[1] == "0.0.0.0" {
			if gw := fields[2]; gw != "" && !strings.HasPrefix(gw, "10.0.85") {
				return gw, nil
			}
		}
	}
	return "", fmt.Errorf("physical gateway not found")
}

func (m *Manager) cleanupGameRouteExcludes() {
	for _, prefix := range m.gameRouteExcludePrefixes() {
		m.removeGameRouteExclude(prefix)
	}
}
