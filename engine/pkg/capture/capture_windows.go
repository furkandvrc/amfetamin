//go:build windows && !cgo

package capture

import "fmt"

func NewCapture(_ string, _ []uint16) (Detector, error) {
	return nil, fmt.Errorf("Npcap support requires CGO build — rebuild with CGO_ENABLED=1 and Npcap installed")
}
