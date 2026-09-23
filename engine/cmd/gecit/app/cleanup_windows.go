package app

import (
	"fmt"
	"os/exec"
	"strings"
	"syscall"

	"github.com/boratanrikulu/gecit/pkg/dns"
	gecittun "github.com/boratanrikulu/gecit/pkg/tun"
)

func platformCleanup() bool {
	cleaned := false

	// Host routes for games outlive the process on Windows.
	if ips := gecittun.ReadRouteState(); len(ips) > 0 {
		fmt.Printf("removing %d game routes...\n", len(ips))
		for _, ip := range ips {
			gecittun.DeleteHostRoute(ip)
		}
		gecittun.RemoveRouteState()
		cleaned = true
	}

	// Routes from very old engine builds (0/1 + 128/1 via the TUN).
	cmd := exec.Command("route", "print", "-4")
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	if out, err := cmd.Output(); err == nil && strings.Contains(string(out), "10.0.85.1") {
		for _, args := range [][]string{
			{"delete", "0.0.0.0", "mask", "128.0.0.0", "10.0.85.2"},
			{"delete", "128.0.0.0", "mask", "128.0.0.0", "10.0.85.2"},
		} {
			c := exec.Command("route", args...)
			c.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
			if c.Run() == nil {
				cleaned = true
			}
		}
	}

	if _, _, err := dns.ReadDNSBackup(); err == nil {
		fmt.Println("restoring DNS...")
		dns.RestoreSystemDNS()
		cleaned = true
	}
	return cleaned
}
