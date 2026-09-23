//go:build darwin || windows

package capture

import (
	"errors"
	"fmt"
	"net"
	"strings"
	"sync"
	"time"

	"github.com/boratanrikulu/gecit/pkg/pcaputil"
	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"
	"github.com/google/gopacket/pcap"
)

// pcapCapture watches the physical NIC for SYN-ACKs from the target ports so
// the real TCP seq/ack of proxied connections is known before fakes are sent.
type pcapCapture struct {
	handle   *pcap.Handle
	stopOnce sync.Once
	done     chan struct{}
}

func NewCapture(iface string, ports []uint16) (Detector, error) {
	dev, err := pcaputil.DeviceForInterface(iface)
	if err != nil {
		return nil, err
	}
	handle, err := pcaputil.OpenLive(dev, 96, 250*time.Millisecond)
	if err != nil {
		return nil, fmt.Errorf("pcap open %s: %w", iface, err)
	}
	if err := handle.SetBPFFilter(synAckFilter(ports)); err != nil {
		handle.Close()
		return nil, fmt.Errorf("set BPF filter: %w", err)
	}
	return &pcapCapture{handle: handle, done: make(chan struct{})}, nil
}

func synAckFilter(ports []uint16) string {
	if len(ports) == 0 {
		ports = []uint16{443}
	}
	parts := make([]string, 0, len(ports))
	for _, p := range ports {
		parts = append(parts, fmt.Sprintf("src port %d", p))
	}
	return fmt.Sprintf("tcp and (%s) and tcp[tcpflags] & (tcp-syn|tcp-ack) = (tcp-syn|tcp-ack)",
		strings.Join(parts, " or "))
}

func (c *pcapCapture) Start(cb Callback) error {
	go func() {
		var (
			eth     layers.Ethernet
			loop    layers.Loopback
			ip4     layers.IPv4
			tcp     layers.TCP
			decoded []gopacket.LayerType
		)
		first := layers.LayerTypeEthernet
		if c.handle.LinkType() == layers.LinkTypeNull || c.handle.LinkType() == layers.LinkTypeLoop {
			first = layers.LayerTypeLoopback
		}
		parser := gopacket.NewDecodingLayerParser(first, &eth, &loop, &ip4, &tcp)
		parser.IgnoreUnsupported = true

		for {
			data, _, err := c.handle.ZeroCopyReadPacketData()
			select {
			case <-c.done:
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
			if err := parser.DecodeLayers(data, &decoded); err != nil && len(decoded) == 0 {
				continue
			}
			if !hasLayers(decoded, layers.LayerTypeIPv4, layers.LayerTypeTCP) || !tcp.SYN || !tcp.ACK {
				continue
			}
			cb(ConnectionEvent{
				SrcIP:   append(net.IP(nil), ip4.DstIP.To4()...), // our IP
				DstIP:   append(net.IP(nil), ip4.SrcIP.To4()...), // server IP
				SrcPort: uint16(tcp.DstPort),                     // our port
				DstPort: uint16(tcp.SrcPort),                     // server port
				Seq:     tcp.Ack,                                 // our snd_nxt
				Ack:     tcp.Seq + 1,                             // our rcv_nxt
			})
		}
	}()
	return nil
}

func hasLayers(decoded []gopacket.LayerType, want ...gopacket.LayerType) bool {
	for _, w := range want {
		found := false
		for _, d := range decoded {
			if d == w {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

func (c *pcapCapture) Stop() error {
	c.stopOnce.Do(func() {
		close(c.done)
		c.handle.Close()
	})
	return nil
}
