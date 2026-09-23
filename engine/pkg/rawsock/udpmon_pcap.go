//go:build darwin || windows

package rawsock

import (
	"errors"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/boratanrikulu/gecit/pkg/pcaputil"
	"github.com/google/gopacket/layers"
	"github.com/google/gopacket/pcap"
)

// monitorUDPInbound captures UDP datagrams addressed to localIP:localPort on
// device and hands their payload to cb. Used by the game relay when the
// game's own source port can't be bound for a bypass socket.
func monitorUDPInbound(device string, localIP net.IP, localPort uint16, cb func(net.IP, uint16, []byte)) (func(), error) {
	h, err := pcaputil.OpenLive(device, 65535, 250*time.Millisecond)
	if err != nil {
		return nil, fmt.Errorf("pcap inbound open: %w", err)
	}
	if err := h.SetBPFFilter(fmt.Sprintf("udp and dst host %s and dst port %d", localIP, localPort)); err != nil {
		h.Close()
		return nil, fmt.Errorf("pcap inbound filter: %w", err)
	}
	loopback := h.LinkType() == layers.LinkTypeNull || h.LinkType() == layers.LinkTypeLoop

	done := make(chan struct{})
	go func() {
		defer h.Close()
		for {
			data, _, err := h.ZeroCopyReadPacketData()
			select {
			case <-done:
				return
			default:
			}
			if err != nil {
				if errors.Is(err, pcap.NextErrorTimeoutExpired) {
					continue
				}
				if errors.Is(err, pcap.NextErrorNoMorePackets) {
					return
				}
				time.Sleep(10 * time.Millisecond)
				continue
			}
			if src, port, payload, ok := parseUDPFrame(data, loopback); ok {
				cb(src, port, payload)
			}
		}
	}()

	var once sync.Once
	return func() { once.Do(func() { close(done) }) }, nil
}

// parseUDPFrame extracts source and payload from an Ethernet (or BSD
// loopback) framed IPv4/UDP packet. The payload is copied.
func parseUDPFrame(data []byte, loopback bool) (net.IP, uint16, []byte, bool) {
	var ip []byte
	switch {
	case loopback:
		if len(data) < 4 {
			return nil, 0, nil, false
		}
		ip = data[4:]
	default:
		if len(data) < 14 || data[12] != 0x08 || data[13] != 0x00 {
			return nil, 0, nil, false
		}
		ip = data[14:]
	}
	if len(ip) < 20 || ip[0]>>4 != 4 || ip[9] != 17 {
		return nil, 0, nil, false
	}
	ihl := int(ip[0]&0x0f) * 4
	if ihl < 20 || len(ip) < ihl+8 {
		return nil, 0, nil, false
	}
	udp := ip[ihl:]
	udpLen := int(udp[4])<<8 | int(udp[5])
	if udpLen < 8 || len(udp) < udpLen {
		return nil, 0, nil, false
	}
	src := net.IP(append([]byte(nil), ip[12:16]...))
	port := uint16(udp[0])<<8 | uint16(udp[1])
	return src, port, append([]byte(nil), udp[8:udpLen]...), true
}
