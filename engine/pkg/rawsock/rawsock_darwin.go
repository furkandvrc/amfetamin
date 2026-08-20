package rawsock

import (
	"fmt"
	"syscall"
)

type platformRawSocket struct {
	fd int
}

func New(_ string) (RawSocket, error) {
	fd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_RAW, syscall.IPPROTO_RAW)
	if err != nil {
		return nil, fmt.Errorf("raw socket: %w (run with sudo)", err)
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

func (s *platformRawSocket) Close() error {
	return syscall.Close(s.fd)
}
