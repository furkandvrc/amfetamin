package rawsock

import (
	"fmt"
	"net"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"github.com/boratanrikulu/gecit/pkg/netif"
	"github.com/boratanrikulu/gecit/pkg/pcaputil"
	"github.com/google/gopacket/pcap"
	"golang.org/x/sys/windows"
)

// pcapRawSocket injects Ethernet frames through Npcap. wpcap.dll is loaded at
// runtime by gopacket, so the engine builds without cgo and starts even when
// Npcap is missing (it then fails here with a clear error).
type pcapRawSocket struct {
	mu     sync.Mutex
	handle *pcap.Handle
	device string
	iface  netif.Info
	srcMAC net.HardwareAddr
	dstMAC net.HardwareAddr
}

func New(iface netif.Info) (RawSocket, error) {
	dev, err := pcaputil.DeviceForInterface(iface.Name)
	if err != nil {
		return nil, fmt.Errorf("resolve pcap device for %s: %w", iface.Name, err)
	}
	handle, err := pcaputil.OpenLive(dev, 96, 250*time.Millisecond)
	if err != nil {
		return nil, fmt.Errorf("pcap open %s: %w (is Npcap installed?)", iface.Name, err)
	}
	// This handle only sends. Without a filter Npcap would still copy every
	// packet on the NIC into its buffer for a reader that never comes.
	_ = handle.SetBPFFilter("less 1")

	s := &pcapRawSocket{handle: handle, device: dev, iface: iface, srcMAC: iface.MAC}
	if len(s.srcMAC) != 6 {
		s.srcMAC = net.HardwareAddr{0, 0, 0, 0, 0, 0}
	}
	s.dstMAC = resolveGatewayMAC(iface)
	return s, nil
}

func (s *pcapRawSocket) SendFake(conn ConnInfo, payload []byte, ttl int) error {
	return s.sendIPv4Frame(BuildPacket(conn, payload, ttl))
}

func (s *pcapRawSocket) SendUDP(conn ConnInfo, payload []byte) error {
	return s.sendIPv4Frame(BuildUDPPacket(conn, payload, 64))
}

func (s *pcapRawSocket) MonitorUDPInbound(localIP net.IP, localPort uint16, cb func(net.IP, uint16, []byte)) (func(), error) {
	return monitorUDPInbound(s.device, localIP, localPort, cb)
}

func (s *pcapRawSocket) sendIPv4Frame(ipPayload []byte) error {
	frame := make([]byte, 14+len(ipPayload))
	copy(frame[0:6], s.dstMAC)
	copy(frame[6:12], s.srcMAC)
	frame[12], frame[13] = 0x08, 0x00
	copy(frame[14:], ipPayload)
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.handle.WritePacketData(frame)
}

func (s *pcapRawSocket) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.handle.Close()
	return nil
}

var (
	modIphlpapi = windows.NewLazySystemDLL("iphlpapi.dll")
	procSendARP = modIphlpapi.NewProc("SendARP")
)

// resolveGatewayMAC finds the next-hop MAC for injected frames. SendARP
// resolves (and if needed, actively ARPs for) the gateway, which works even
// when the ARP cache is cold; `arp -a` is the fallback. Broadcast is the last
// resort — most routers drop broadcast-addressed unicast IP.
func resolveGatewayMAC(iface netif.Info) net.HardwareAddr {
	gw := iface.Gateway
	if gw == nil {
		gw = netif.GatewayFor(iface.IP)
	}
	if gw != nil {
		if mac := sendARP(gw, iface.IP); mac != nil {
			return mac
		}
		if mac := arpTableMAC(gw); mac != nil {
			return mac
		}
	}
	return net.HardwareAddr{0xff, 0xff, 0xff, 0xff, 0xff, 0xff}
}

func sendARP(dst, src net.IP) net.HardwareAddr {
	if err := procSendARP.Find(); err != nil {
		return nil
	}
	d4, s4 := dst.To4(), src.To4()
	if d4 == nil {
		return nil
	}
	destIP := *(*uint32)(unsafe.Pointer(&d4[0]))
	var srcIP uint32
	if s4 != nil {
		srcIP = *(*uint32)(unsafe.Pointer(&s4[0]))
	}
	var mac [8]byte
	macLen := uint32(len(mac))
	r, _, _ := procSendARP.Call(uintptr(destIP), uintptr(srcIP), uintptr(unsafe.Pointer(&mac[0])), uintptr(unsafe.Pointer(&macLen)))
	if r != 0 || macLen < 6 {
		return nil
	}
	return net.HardwareAddr(append([]byte(nil), mac[:6]...))
}

func arpTableMAC(gw net.IP) net.HardwareAddr {
	cmd := exec.Command("arp", "-a")
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	out, err := cmd.Output()
	if err != nil {
		return nil
	}
	want := gw.String()
	for _, line := range strings.Split(string(out), "\n") {
		f := strings.Fields(strings.TrimSpace(line))
		if len(f) >= 2 && f[0] == want {
			if mac, err := net.ParseMAC(strings.ReplaceAll(f[1], "-", ":")); err == nil {
				return mac
			}
		}
	}
	return nil
}
