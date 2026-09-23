package capture

import (
	"github.com/boratanrikulu/gecit/pkg/rawsock"
)

// ConnectionEvent is emitted when a SYN-ACK for a proxied connection is seen.
type ConnectionEvent = rawsock.ConnInfo

// Callback is called for each captured SYN-ACK.
type Callback func(evt ConnectionEvent)

// Detector reports new TLS connections. Linux uses eBPF sock_ops instead;
// macOS (libpcap) and Windows (Npcap) capture SYN-ACKs on the physical NIC.
type Detector interface {
	Start(cb Callback) error
	Stop() error
}
