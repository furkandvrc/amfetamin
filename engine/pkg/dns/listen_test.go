package dns

import (
	"net"
	"testing"

	"github.com/sirupsen/logrus"
)

// When 127.0.0.1:53 is taken (another DNS service, a stale engine), the
// server must move to the next loopback address instead of failing.
func TestStartFallsBackWhenPort53Busy(t *testing.T) {
	if hold, err := net.ListenPacket("udp", "127.0.0.1:53"); err == nil {
		defer hold.Close()
	} // else: already held by something else, which is exactly the case under test

	s := NewServer("cloudflare", logrus.New(), nil)
	if err := s.Start(); err != nil {
		t.Skipf("no free loopback DNS address on this machine: %v", err)
	}
	defer s.Stop()
	if ip := ActiveIP(); ip == "127.0.0.1" || !IsOurAddress(ip) {
		t.Fatalf("expected a fallback address, got %s", ip)
	}
}
