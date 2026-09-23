//go:build darwin || windows

package rawsock

import (
	"net"
	"testing"
)

func TestParseUDPFrame(t *testing.T) {
	conn := ConnInfo{
		SrcIP: net.IPv4(203, 0, 113, 9), DstIP: net.IPv4(192, 168, 1, 20),
		SrcPort: 7777, DstPort: 4950,
	}
	ip := BuildUDPPacket(conn, []byte("hello"), 64)
	// BuildUDPPacket writes the length in host order on darwin; the parser
	// only relies on the UDP header, which is always network order.
	frame := append(make([]byte, 14), ip...)
	frame[12], frame[13] = 0x08, 0x00

	src, port, payload, ok := parseUDPFrame(frame, false)
	if !ok || !src.Equal(conn.SrcIP.To4()) || port != 7777 || string(payload) != "hello" {
		t.Fatalf("got %v %v %d %q", ok, src, port, payload)
	}
	if _, _, _, ok := parseUDPFrame(frame[:20], false); ok {
		t.Fatal("truncated frame must be rejected")
	}
}
