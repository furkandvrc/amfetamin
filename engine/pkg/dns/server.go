package dns

import (
	"fmt"
	"net"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/miekg/dns"
	"github.com/sirupsen/logrus"
)

const (
	listenAddr = "127.0.0.1:53"

	// Per-IP hostname memory used for logging and Discord detection.
	maxNamesPerIP = 4
	nameTTL       = 30 * time.Minute
	maxNameIPs    = 20000

	// Response cache.
	maxCacheEntries = 4096
	minCacheTTL     = 30 * time.Second
	maxCacheTTL     = 30 * time.Minute
	negativeTTL     = 60 * time.Second
)

type ResolveHook func(domain string, ips []string)

type Options struct {
	// FilterAAAA answers AAAA queries with an empty NOERROR. The TUN only
	// carries IPv4, so IPv6 answers would let apps route around it (and
	// around the DPI bypass) on dual-stack connections.
	FilterAAAA bool
}

type nameEntry struct {
	names   []string
	expires time.Time
}

type cacheEntry struct {
	msg     *dns.Msg
	stored  time.Time
	expires time.Time
}

type Server struct {
	resolver Resolver
	upstream string
	opts     Options
	logger   *logrus.Logger

	servers []*dns.Server

	mu        sync.Mutex
	names     map[string]*nameEntry
	lastPrune time.Time
	onResolve ResolveHook

	cacheMu sync.Mutex
	cache   map[string]*cacheEntry
}

var globalDNS atomic.Pointer[Server]

// GetDNSServer returns the running server, if any.
func GetDNSServer() *Server { return globalDNS.Load() }

func NewServer(upstream string, logger *logrus.Logger, dial DialFunc, opts ...Options) *Server {
	s := &Server{
		resolver: NewResolver(upstream, dial),
		upstream: upstream,
		logger:   logger,
		names:    make(map[string]*nameEntry),
		cache:    make(map[string]*cacheEntry),
	}
	if len(opts) > 0 {
		s.opts = opts[0]
	}
	globalDNS.Store(s)
	return s
}

func (s *Server) SetResolveHook(h ResolveHook) {
	s.mu.Lock()
	s.onResolve = h
	s.mu.Unlock()
}

// DomainsForIP returns hostnames recently resolved to ip (oldest first).
func (s *Server) DomainsForIP(ip string) []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	e := s.names[ip]
	if e == nil || time.Now().After(e.expires) {
		return nil
	}
	return append([]string(nil), e.names...)
}

func (s *Server) rememberNames(domain string, ips []string) {
	now := time.Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, ip := range ips {
		e := s.names[ip]
		if e == nil {
			e = &nameEntry{}
			s.names[ip] = e
		}
		e.expires = now.Add(nameTTL)
		found := false
		for _, n := range e.names {
			if n == domain {
				found = true
				break
			}
		}
		if !found {
			e.names = append(e.names, domain)
			if len(e.names) > maxNamesPerIP {
				e.names = e.names[len(e.names)-maxNamesPerIP:]
			}
		}
	}
	if len(s.names) > maxNameIPs || now.Sub(s.lastPrune) > 5*time.Minute {
		s.lastPrune = now
		for ip, e := range s.names {
			if now.After(e.expires) {
				delete(s.names, ip)
			}
		}
	}
}

func (s *Server) Start() error {
	mux := dns.NewServeMux()
	mux.HandleFunc(".", s.handleQuery)

	// UDP is what stub resolvers use and is required. TCP only serves
	// clients retrying truncated answers, so it's best effort.
	if err := s.listen("udp", mux); err != nil {
		return fmt.Errorf("DNS server (udp %s): %w — is another DNS service using port 53?", listenAddr, err)
	}
	if err := s.listen("tcp", mux); err != nil {
		s.logger.WithError(err).Warn("DNS TCP listener unavailable")
	}

	s.logger.WithFields(logrus.Fields{
		"addr":        listenAddr,
		"upstream":    s.upstream,
		"filter_aaaa": s.opts.FilterAAAA,
	}).Info("DNS server started")
	return nil
}

func (s *Server) listen(network string, handler dns.Handler) error {
	srv := &dns.Server{Addr: listenAddr, Net: network, Handler: handler}
	started := make(chan error, 1)
	srv.NotifyStartedFunc = func() { started <- nil }
	go func() {
		if err := srv.ListenAndServe(); err != nil {
			select {
			case started <- err:
			default:
				s.logger.WithError(err).WithField("net", network).Error("DNS server stopped")
			}
		}
	}()
	select {
	case err := <-started:
		if err != nil {
			return err
		}
	case <-time.After(5 * time.Second):
		srv.Shutdown()
		return fmt.Errorf("listener did not start")
	}
	s.servers = append(s.servers, srv)
	return nil
}

func (s *Server) Stop() error {
	for _, srv := range s.servers {
		srv.Shutdown()
	}
	s.servers = nil
	globalDNS.CompareAndSwap(s, nil)
	return nil
}

func cacheKey(q dns.Question) string {
	return strings.ToLower(q.Name) + "|" + dns.TypeToString[q.Qtype] + "|" + dns.ClassToString[q.Qclass]
}

func (s *Server) cached(q dns.Question) *dns.Msg {
	key := cacheKey(q)
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	e := s.cache[key]
	if e == nil {
		return nil
	}
	now := time.Now()
	if now.After(e.expires) {
		delete(s.cache, key)
		return nil
	}
	msg := e.msg.Copy()
	// Age the TTLs so clients don't cache longer than the upstream allowed.
	age := uint32(now.Sub(e.stored) / time.Second)
	for _, sec := range [][]dns.RR{msg.Answer, msg.Ns, msg.Extra} {
		for _, rr := range sec {
			if h := rr.Header(); h.Rrtype != dns.TypeOPT {
				if h.Ttl > age {
					h.Ttl -= age
				} else {
					h.Ttl = 1
				}
			}
		}
	}
	return msg
}

func (s *Server) store(q dns.Question, msg *dns.Msg) {
	if msg.Truncated || (msg.Rcode != dns.RcodeSuccess && msg.Rcode != dns.RcodeNameError) {
		return
	}
	ttl := negativeTTL
	if len(msg.Answer) > 0 {
		min := uint32(1 << 31)
		for _, rr := range msg.Answer {
			if t := rr.Header().Ttl; t < min {
				min = t
			}
		}
		ttl = time.Duration(min) * time.Second
	}
	if ttl < minCacheTTL {
		ttl = minCacheTTL
	}
	if ttl > maxCacheTTL {
		ttl = maxCacheTTL
	}

	now := time.Now()
	key := cacheKey(q)
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	if len(s.cache) >= maxCacheEntries {
		for k, e := range s.cache {
			if now.After(e.expires) {
				delete(s.cache, k)
			}
		}
		// Still full: drop an arbitrary quarter.
		if len(s.cache) >= maxCacheEntries {
			n := 0
			for k := range s.cache {
				delete(s.cache, k)
				if n++; n >= maxCacheEntries/4 {
					break
				}
			}
		}
	}
	s.cache[key] = &cacheEntry{msg: msg.Copy(), stored: now, expires: now.Add(ttl)}
}

func (s *Server) handleQuery(w dns.ResponseWriter, r *dns.Msg) {
	if len(r.Question) != 1 {
		s.reply(w, r, dns.RcodeFormatError)
		return
	}
	q := r.Question[0]

	if s.opts.FilterAAAA && q.Qtype == dns.TypeAAAA {
		resp := new(dns.Msg)
		resp.SetReply(r)
		resp.RecursionAvailable = true
		s.write(w, r, resp)
		return
	}

	resp := s.cached(q)
	via := "cache"
	if resp == nil {
		query := r.Copy()
		query.Id = dns.Id()
		packed, err := query.Pack()
		if err != nil {
			s.reply(w, r, dns.RcodeServerFailure)
			return
		}
		result, err := s.resolver.Resolve(packed)
		if err != nil {
			s.logger.WithError(err).WithField("domain", q.Name).Debug("DNS resolve failed")
			s.reply(w, r, dns.RcodeServerFailure)
			return
		}
		resp = new(dns.Msg)
		if err := resp.Unpack(result.Data); err != nil {
			s.reply(w, r, dns.RcodeServerFailure)
			return
		}
		via = result.Via
		s.store(q, resp)
	}

	resp.Id = r.Id
	resp.Question = r.Question
	s.write(w, r, resp)

	if q.Qtype != dns.TypeA && q.Qtype != dns.TypeAAAA {
		return
	}
	var ips []string
	for _, rr := range resp.Answer {
		switch rec := rr.(type) {
		case *dns.A:
			ips = append(ips, rec.A.String())
		case *dns.AAAA:
			ips = append(ips, rec.AAAA.String())
		}
	}
	if len(ips) == 0 {
		return
	}
	domain := strings.TrimSuffix(q.Name, ".")
	s.rememberNames(domain, ips)
	if s.logger.IsLevelEnabled(logrus.DebugLevel) {
		s.logger.WithFields(logrus.Fields{"domain": domain, "ips": strings.Join(ips, ","), "via": via}).Debug("DNS resolved")
	}
	s.mu.Lock()
	hook := s.onResolve
	s.mu.Unlock()
	if hook != nil {
		hook(domain, ips)
	}
}

// write sends resp, truncating for UDP clients that didn't advertise a
// larger buffer so they retry over TCP instead of failing.
func (s *Server) write(w dns.ResponseWriter, r, resp *dns.Msg) {
	if _, isUDP := w.RemoteAddr().(*net.UDPAddr); isUDP {
		size := dns.MinMsgSize
		if opt := r.IsEdns0(); opt != nil && int(opt.UDPSize()) > size {
			size = int(opt.UDPSize())
		}
		resp.Truncate(size)
	}
	if err := w.WriteMsg(resp); err != nil {
		s.logger.WithError(err).Debug("failed to write DNS response")
	}
}

func (s *Server) reply(w dns.ResponseWriter, r *dns.Msg, rcode int) {
	resp := new(dns.Msg)
	resp.SetRcode(r, rcode)
	w.WriteMsg(resp)
}
