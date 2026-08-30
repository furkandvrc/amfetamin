package rawsock

import (
	"fmt"
	"net"
	"syscall"
)

type platformRawSocket struct {
	fd int
}

func New(_ string) (RawSocket, error) {
	fd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_RAW, syscall.IPPROTO_RAW)
	if err != nil {
		return nil, fmt.Errorf("raw socket: %w", err)
	}

	if err := syscall.SetsockoptInt(fd, syscall.IPPROTO_IP, syscall.IP_HDRINCL, 1); err != nil {
		syscall.Close(fd)
		return nil, fmt.Errorf("IP_HDRINCL: %w", err)
	}

	return &platformRawSocket{fd: fd}, nil
}

func (s *platformRawSocket) SendFake(conn ConnInfo, payload []byte, ttl int) error {
	pkt := BuildPacket(conn, payload, ttl)

	addr := syscall.SockaddrInet4{Port: 0}
	copy(addr.Addr[:], conn.DstIP.To4())

	return syscall.Sendto(s.fd, pkt, 0, &addr)
}

func (s *platformRawSocket) SendUDP(conn ConnInfo, payload []byte) error {
	pkt := BuildUDPPacket(conn, payload, 64)

	addr := syscall.SockaddrInet4{Port: 0}
	copy(addr.Addr[:], conn.DstIP.To4())

	return syscall.Sendto(s.fd, pkt, 0, &addr)
}

func (s *platformRawSocket) MonitorUDPInbound(_ net.IP, _ uint16, _ func(net.IP, uint16, []byte)) (func(), error) {
	return func() {}, nil
}

func (s *platformRawSocket) Close() error {
	return syscall.Close(s.fd)
}
