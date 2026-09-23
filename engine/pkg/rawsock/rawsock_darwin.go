package rawsock

import (
	"fmt"
	"net"
	"syscall"

	"github.com/boratanrikulu/gecit/pkg/netif"
	"github.com/boratanrikulu/gecit/pkg/pcaputil"
	"golang.org/x/sys/unix"
)

type platformRawSocket struct {
	fd    int
	iface netif.Info
}

// New opens a raw IPv4 socket pinned to the physical interface.
//
// The TUN device owns the default route while the engine runs, so an
// unbound raw socket would route fakes straight back into utun and they
// would never reach the wire. IP_BOUND_IF forces egress on the physical NIC.
func New(iface netif.Info) (RawSocket, error) {
	fd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_RAW, syscall.IPPROTO_RAW)
	if err != nil {
		return nil, fmt.Errorf("raw socket: %w (run with sudo)", err)
	}
	if err := syscall.SetsockoptInt(fd, syscall.IPPROTO_IP, syscall.IP_HDRINCL, 1); err != nil {
		syscall.Close(fd)
		return nil, fmt.Errorf("IP_HDRINCL: %w", err)
	}
	if iface.Index > 0 {
		if err := syscall.SetsockoptInt(fd, syscall.IPPROTO_IP, unix.IP_BOUND_IF, iface.Index); err != nil {
			syscall.Close(fd)
			return nil, fmt.Errorf("IP_BOUND_IF %s: %w", iface.Name, err)
		}
	}
	return &platformRawSocket{fd: fd, iface: iface}, nil
}

func (s *platformRawSocket) SendFake(conn ConnInfo, payload []byte, ttl int) error {
	return s.send(conn.DstIP, BuildPacket(conn, payload, ttl))
}

func (s *platformRawSocket) SendUDP(conn ConnInfo, payload []byte) error {
	return s.send(conn.DstIP, BuildUDPPacket(conn, payload, 64))
}

func (s *platformRawSocket) send(dst net.IP, pkt []byte) error {
	addr := syscall.SockaddrInet4{}
	copy(addr.Addr[:], dst.To4())
	return syscall.Sendto(s.fd, pkt, 0, &addr)
}

func (s *platformRawSocket) MonitorUDPInbound(localIP net.IP, localPort uint16, cb func(net.IP, uint16, []byte)) (func(), error) {
	dev, err := pcaputil.DeviceForInterface(s.iface.Name)
	if err != nil {
		return nil, err
	}
	return monitorUDPInbound(dev, localIP, localPort, cb)
}

func (s *platformRawSocket) Close() error {
	return syscall.Close(s.fd)
}
