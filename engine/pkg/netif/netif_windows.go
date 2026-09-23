package netif

import (
	"net"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"syscall"

	"golang.org/x/sys/windows"
)

// platformDefault asks Windows which interface would carry traffic to a
// public address. Must be called before the TUN routes are installed.
func platformDefault() (Info, error) {
	var idx uint32
	if err := windows.GetBestInterfaceEx(&windows.SockaddrInet4{Addr: [4]byte{1, 1, 1, 1}}, &idx); err != nil {
		return Info{}, err
	}
	iface, err := net.InterfaceByIndex(int(idx))
	if err != nil {
		return Info{}, err
	}
	if strings.HasPrefix(strings.ToLower(iface.Name), "utun") {
		return Info{}, errNoDefault
	}
	ip := IPv4Of(iface)
	if ip == nil {
		return Info{}, errNoDefault
	}
	return Info{
		Name:    iface.Name,
		Index:   iface.Index,
		IP:      ip,
		Gateway: GatewayFor(ip),
		MAC:     iface.HardwareAddr,
	}, nil
}

type routeRow struct {
	gw     net.IP
	iface  net.IP
	metric int
}

// GatewayFor returns the default gateway reachable through the interface
// that owns localIP, parsed from `route print` (the numeric table is not
// localized). The TUN's own default route is ignored.
func GatewayFor(localIP net.IP) net.IP {
	cmd := exec.Command("route", "print", "-4", "0.0.0.0")
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	out, err := cmd.Output()
	if err != nil {
		return nil
	}
	var rows []routeRow
	for _, line := range strings.Split(string(out), "\n") {
		f := strings.Fields(strings.TrimSpace(line))
		if len(f) < 5 || f[0] != "0.0.0.0" || f[1] != "0.0.0.0" {
			continue
		}
		gw := net.ParseIP(f[2]).To4()
		ifIP := net.ParseIP(f[3]).To4()
		metric, _ := strconv.Atoi(f[4])
		if gw == nil || ifIP == nil || ifIP.Equal(TUNAddr) || strings.HasPrefix(f[2], "10.0.85.") {
			continue
		}
		rows = append(rows, routeRow{gw: gw, iface: ifIP, metric: metric})
	}
	sort.SliceStable(rows, func(i, j int) bool { return rows[i].metric < rows[j].metric })
	for _, r := range rows {
		if localIP != nil && r.iface.Equal(localIP) {
			return r.gw
		}
	}
	if len(rows) > 0 {
		return rows[0].gw
	}
	return nil
}
