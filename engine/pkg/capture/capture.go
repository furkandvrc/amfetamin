package capture

import (
	"github.com/boratanrikulu/gecit/pkg/rawsock"
)

// ConnectionEvent is emitted when a new TLS connection is detected.
type ConnectionEvent = rawsock.ConnInfo

// Callback is called for each new TLS connection detected.
type Callback func(evt ConnectionEvent)

// Detector detects new TLS connections and emits events.
// Linux uses eBPF sock_ops (not this interface).
// macOS uses BPF device capture.
// Windows will use WinDivert.
type Detector interface {
	// Start begins capturing and calls cb for each new connection.
	Start(cb Callback) error
	// Stop stops capturing.
	Stop() error
}
