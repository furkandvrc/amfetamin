//go:build darwin || windows

package capture

import "testing"

func TestSynAckFilter(t *testing.T) {
	got := synAckFilter([]uint16{443, 8443})
	want := "tcp and (src port 443 or src port 8443) and tcp[tcpflags] & (tcp-syn|tcp-ack) = (tcp-syn|tcp-ack)"
	if got != want {
		t.Fatalf("got %q", got)
	}
	if synAckFilter(nil) != "tcp and (src port 443) and tcp[tcpflags] & (tcp-syn|tcp-ack) = (tcp-syn|tcp-ack)" {
		t.Fatal("default port should be 443")
	}
}
