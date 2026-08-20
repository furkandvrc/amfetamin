//go:build windows && !cgo

package rawsock

import "fmt"

func New(_ string) (RawSocket, error) {
	return nil, fmt.Errorf("Npcap support requires CGO build — rebuild with CGO_ENABLED=1 and Npcap installed")
}
