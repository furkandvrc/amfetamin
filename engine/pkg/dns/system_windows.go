package dns

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"unsafe"

	"github.com/boratanrikulu/gecit/pkg/netif"
	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

// The backup file keeps the previous DNS so `cleanup` can restore it after a
// crash. Format: line 1 = "dhcp" or space-separated IPv4 servers, line 2 =
// interface name.

var savedInterface string

func netsh(args ...string) ([]byte, error) {
	cmd := exec.Command("netsh", args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	return cmd.CombinedOutput()
}

// SetSystemDNS points the physical interface at the local DoH server.
func SetSystemDNS(ifaceName ...string) error {
	iface := ""
	if len(ifaceName) > 0 {
		iface = ifaceName[0]
	}
	if iface == "" {
		info, err := netif.Default("")
		if err != nil {
			return fmt.Errorf("detect interface: %w", err)
		}
		iface = info.Name
	}
	savedInterface = iface

	// A backup left by a crashed run holds the user's real settings; restore
	// them first so we don't back up our own 127.0.0.1.
	if data, _, err := ReadDNSBackup(); err == nil {
		prev, prevIface := parseBackup(data)
		if prevIface != "" {
			applyDNS(prevIface, prev)
		}
	}

	current := currentDNS(iface)
	if err := os.WriteFile(primaryDNSBackupPath(), []byte(current+"\n"+iface+"\n"), 0o644); err != nil {
		return fmt.Errorf("write DNS backup: %w", err)
	}

	if out, err := netsh("interface", "ipv4", "set", "dnsservers", "name="+iface, "source=static", "address="+ActiveIP(), "register=none", "validate=no"); err != nil {
		return fmt.Errorf("set DNS on %q: %s: %w", iface, strings.TrimSpace(string(out)), err)
	}
	flushDNS()
	return nil
}

// RestoreSystemDNS puts back what SetSystemDNS replaced.
func RestoreSystemDNS(_ ...string) error {
	data, _, err := ReadDNSBackup()
	if err != nil {
		iface := savedInterface
		if iface == "" {
			if info, e := netif.Default(""); e == nil {
				iface = info.Name
			}
		}
		if iface != "" && IsOurAddress(currentDNS(iface)) {
			applyDNS(iface, "dhcp")
		}
		flushDNS()
		return nil
	}
	prev, iface := parseBackup(data)
	if iface == "" {
		iface = savedInterface
	}
	if iface != "" {
		applyDNS(iface, prev)
	}
	flushDNS()
	RemoveDNSBackupFiles()
	return nil
}

func parseBackup(data []byte) (servers, iface string) {
	lines := strings.SplitN(strings.ReplaceAll(string(data), "\r", ""), "\n", 3)
	servers = "dhcp"
	if len(lines) >= 1 && strings.TrimSpace(lines[0]) != "" {
		servers = strings.TrimSpace(lines[0])
	}
	if len(lines) >= 2 {
		iface = strings.TrimSpace(lines[1])
	}
	return servers, iface
}

// applyDNS sets iface to DHCP or to the given static servers.
func applyDNS(iface, servers string) {
	var list []string
	for _, s := range strings.Fields(servers) {
		if ip := net.ParseIP(s); ip != nil && ip.To4() != nil && !ip.IsLoopback() {
			list = append(list, s)
		}
	}
	if servers == "dhcp" || len(list) == 0 {
		netsh("interface", "ipv4", "set", "dnsservers", "name="+iface, "source=dhcp")
		return
	}
	netsh("interface", "ipv4", "set", "dnsservers", "name="+iface, "source=static", "address="+list[0], "register=primary", "validate=no")
	for i, s := range list[1:] {
		netsh("interface", "ipv4", "add", "dnsservers", "name="+iface, "address="+s, fmt.Sprintf("index=%d", i+2), "validate=no")
	}
}

func flushDNS() {
	cmd := exec.Command("ipconfig", "/flushdns")
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	cmd.Run()
}

// currentDNS returns "dhcp" when the interface gets DNS from DHCP, otherwise
// the statically configured servers. It reads the TCP/IP registry key, which
// (unlike netsh output) is not localized.
func currentDNS(iface string) string {
	guid := adapterGUID(iface)
	if guid == "" {
		return "dhcp"
	}
	k, err := registry.OpenKey(registry.LOCAL_MACHINE,
		`SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\`+guid, registry.QUERY_VALUE)
	if err != nil {
		return "dhcp"
	}
	defer k.Close()
	v, _, err := k.GetStringValue("NameServer")
	if err != nil {
		return "dhcp"
	}
	v = strings.TrimSpace(strings.ReplaceAll(v, ",", " "))
	if v == "" {
		return "dhcp"
	}
	return v
}

// adapterGUID maps an interface's friendly name to its adapter GUID.
func adapterGUID(iface string) string {
	ifi, err := net.InterfaceByName(iface)
	if err != nil {
		return ""
	}
	size := uint32(15000)
	for attempt := 0; attempt < 3; attempt++ {
		b := make([]byte, size)
		aa := (*windows.IpAdapterAddresses)(unsafe.Pointer(&b[0]))
		err := windows.GetAdaptersAddresses(windows.AF_UNSPEC, windows.GAA_FLAG_SKIP_ANYCAST|windows.GAA_FLAG_SKIP_MULTICAST|windows.GAA_FLAG_SKIP_DNS_SERVER, 0, aa, &size)
		if err == windows.ERROR_BUFFER_OVERFLOW {
			continue
		}
		if err != nil {
			return ""
		}
		for ; aa != nil; aa = aa.Next {
			if int(aa.IfIndex) == ifi.Index {
				return windows.BytePtrToString(aa.AdapterName)
			}
		}
		return ""
	}
	return ""
}
