package netif

import (
	"net"
	"os/exec"
	"strings"
)

// platformDefault parses `route -n get default`. Must be called before the
// TUN device installs its routes, otherwise utun85 is reported.
func platformDefault() (Info, error) {
	out, err := exec.Command("/sbin/route", "-n", "get", "default").Output()
	if err != nil {
		return Info{}, err
	}
	var ifName string
	var gw net.IP
	for _, line := range strings.Split(string(out), "\n") {
		k, v, ok := strings.Cut(strings.TrimSpace(line), ":")
		if !ok {
			continue
		}
		v = strings.TrimSpace(v)
		switch k {
		case "interface":
			ifName = v
		case "gateway":
			gw = net.ParseIP(v).To4()
		}
	}
	if ifName == "" || strings.HasPrefix(ifName, "utun") {
		return Info{}, errNoDefault
	}
	return byName(ifName, gw)
}
