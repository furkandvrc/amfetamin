package dns

import (
	"fmt"
	"testing"

	"github.com/miekg/dns"
	"github.com/sirupsen/logrus"
)

func newTestServer() *Server {
	return &Server{
		names:  make(map[string]*nameEntry),
		cache:  make(map[string]*cacheEntry),
		logger: logrus.New(),
	}
}

func TestDomainsForIP(t *testing.T) {
	s := newTestServer()
	if got := s.DomainsForIP("1.2.3.4"); got != nil {
		t.Fatalf("empty: got %v", got)
	}
	s.rememberNames("a.example", []string{"1.2.3.4"})
	s.rememberNames("a.example", []string{"1.2.3.4"})
	s.rememberNames("b.example", []string{"1.2.3.4", "5.6.7.8"})
	if got := s.DomainsForIP("1.2.3.4"); len(got) != 2 || got[0] != "a.example" || got[1] != "b.example" {
		t.Fatalf("got %v", got)
	}
	if got := s.DomainsForIP("5.6.7.8"); len(got) != 1 {
		t.Fatalf("got %v", got)
	}
}

func TestDomainsForIPBounded(t *testing.T) {
	s := newTestServer()
	for i := 0; i < 100; i++ {
		s.rememberNames(fmt.Sprintf("d%d.example", i), []string{"9.9.9.9"})
	}
	got := s.DomainsForIP("9.9.9.9")
	if len(got) != maxNamesPerIP || got[len(got)-1] != "d99.example" {
		t.Fatalf("expected last %d names, got %v", maxNamesPerIP, got)
	}
}

func TestCacheRoundTrip(t *testing.T) {
	s := newTestServer()
	q := dns.Question{Name: "example.com.", Qtype: dns.TypeA, Qclass: dns.ClassINET}
	if s.cached(q) != nil {
		t.Fatal("cache should start empty")
	}
	msg := new(dns.Msg)
	rr, _ := dns.NewRR("example.com. 300 IN A 93.184.216.34")
	msg.Answer = append(msg.Answer, rr)
	s.store(q, msg)

	got := s.cached(dns.Question{Name: "EXAMPLE.com.", Qtype: dns.TypeA, Qclass: dns.ClassINET})
	if got == nil || len(got.Answer) != 1 {
		t.Fatalf("expected cached answer, got %v", got)
	}
	if got.Answer[0].Header().Ttl > 300 {
		t.Fatalf("ttl should not grow: %d", got.Answer[0].Header().Ttl)
	}

	failed := new(dns.Msg)
	failed.Rcode = dns.RcodeServerFailure
	q2 := dns.Question{Name: "fail.example.", Qtype: dns.TypeA, Qclass: dns.ClassINET}
	s.store(q2, failed)
	if s.cached(q2) != nil {
		t.Fatal("SERVFAIL must not be cached")
	}
}

func TestNewServerSetsGlobal(t *testing.T) {
	s := NewServer("cloudflare", logrus.New(), nil)
	if GetDNSServer() != s {
		t.Fatal("GetDNSServer() should return the server set by NewServer()")
	}
	s.Stop()
	if GetDNSServer() != nil {
		t.Fatal("Stop should clear the global server")
	}
}
