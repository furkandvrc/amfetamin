// Package netif finds the physical interface that carries the default route.
//
// Picking "the first interface that is up and has an IPv4 address" breaks on
// machines with VirtualBox/Hyper-V/WSL/VPN adapters, so the platform code asks
// the OS routing table instead.
package netif

import (
	"fmt"
	"net"
	"strings"
)

// TUNAddr is the address the engine assigns to its TUN device. It must never
// be treated as a physical interface address.
var TUNAddr = net.IPv4(10, 0, 85, 1)

// Info describes the physical uplink.
type Info struct {
	Name    string // OS interface name ("en0", "Wi-Fi")
	Index   int
	IP      net.IP // primary IPv4 address
	Gateway net.IP // default gateway, may be nil
	MAC     net.HardwareAddr
}

func (i Info) String() string {
	gw := "?"
	if i.Gateway != nil {
		gw = i.Gateway.String()
	}
	return fmt.Sprintf("%s (ip=%s gw=%s)", i.Name, i.IP, gw)
}

// Default returns the interface that carries the default IPv4 route. When a
// name is given it is used as-is and only its addresses are resolved.
func Default(name string) (Info, error) {
	if name != "" {
		return byName(name, nil)
	}
	if info, err := platformDefault(); err == nil && info.Name != "" {
		return info, nil
	}
	return fallback()
}

func byName(name string, gw net.IP) (Info, error) {
	iface, err := net.InterfaceByName(name)
	if err != nil {
		return Info{}, fmt.Errorf("interface %q: %w", name, err)
	}
	ip := IPv4Of(iface)
	if ip == nil {
		return Info{}, fmt.Errorf("interface %q has no IPv4 address", name)
	}
	return Info{Name: iface.Name, Index: iface.Index, IP: ip, Gateway: gw, MAC: iface.HardwareAddr}, nil
}

// IPv4Of returns the first usable IPv4 address of iface.
func IPv4Of(iface *net.Interface) net.IP {
	addrs, err := iface.Addrs()
	if err != nil {
		return nil
	}
	for _, a := range addrs {
		ipNet, ok := a.(*net.IPNet)
		if !ok {
			continue
		}
		ip4 := ipNet.IP.To4()
		if ip4 == nil || ip4.IsLoopback() || ip4.IsLinkLocalUnicast() || ip4.Equal(TUNAddr) {
			continue
		}
		return ip4
	}
	return nil
}

var virtualPrefixes = []string{
	"utun", "bridge", "veth", "vmnet", "lo", "awdl", "llw", "gif", "stf", "anpi", "ap",
	"vethernet", "virtualbox", "vmware", "hyper-v", "zerotier", "tailscale", "wintun", "wireguard",
	"openvpn", "tap", "tun", "radmin", "hamachi", "npcap loopback",
}

func looksVirtual(name string) bool {
	n := strings.ToLower(name)
	for _, p := range virtualPrefixes {
		if strings.HasPrefix(n, p) {
			return true
		}
	}
	return false
}

// fallback picks the first non-virtual interface with an IPv4 address.
func fallback() (Info, error) {
	ifaces, err := net.Interfaces()
	if err != nil {
		return Info{}, err
	}
	for pass := 0; pass < 2; pass++ {
		for i := range ifaces {
			iface := &ifaces[i]
			if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
				continue
			}
			if pass == 0 && looksVirtual(iface.Name) {
				continue
			}
			if ip := IPv4Of(iface); ip != nil {
				return Info{Name: iface.Name, Index: iface.Index, IP: ip, MAC: iface.HardwareAddr}, nil
			}
		}
	}
	return Info{}, fmt.Errorf("no usable network interface found")
}
