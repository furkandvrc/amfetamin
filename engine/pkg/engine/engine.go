package engine

import "context"

// Engine is the platform-specific DPI bypass implementation.
// Linux uses eBPF sock_ops; macOS and Windows use a TUN transparent proxy.
type Engine interface {
	// Start activates the DPI bypass mechanism.
	Start(ctx context.Context) error
	// Stop deactivates and cleans up all rules/programs.
	Stop() error
	// Mode returns the bypass mechanism name (e.g. "ebpf-sockops", "tun").
	Mode() string
}
