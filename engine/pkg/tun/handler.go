//go:build (darwin || windows) && with_gvisor

package tun

import (
	"context"
	"errors"
	"io"
	"net"
	"net/netip"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	gecitdns "github.com/boratanrikulu/gecit/pkg/dns"
	"github.com/boratanrikulu/gecit/pkg/fake"
	"github.com/boratanrikulu/gecit/pkg/rawsock"
	"github.com/boratanrikulu/gecit/pkg/seqtrack"
	singtun "github.com/sagernet/sing-tun"
	"github.com/sagernet/sing/common/buf"
	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
	"github.com/sirupsen/logrus"
)

const (
	dialTimeout      = 5 * time.Second
	helloReadTimeout = 3 * time.Second
	tcpIdleTimeout   = 2 * time.Hour
	udpIdleTimeout   = 60 * time.Second
	fakeCount        = 3
)

// pipeIdleCheck is how often a quiet direction re-checks the connection-wide idle clock.
var pipeIdleCheck = time.Minute

type handler struct {
	mgr *Manager
}

func (h *handler) PrepareConnection(
	network string, source M.Socksaddr, destination M.Socksaddr,
	_ singtun.DirectRouteContext, _ time.Duration,
) (singtun.DirectRouteDestination, error) {
	// The gvisor stack treats any error here as reject; bypassing happens in
	// New*ConnectionEx instead.
	return nil, nil
}

func (h *handler) NewConnectionEx(ctx context.Context, conn net.Conn, source, destination M.Socksaddr, onClose N.CloseHandlerFunc) {
	if onClose != nil {
		defer onClose(nil)
	}
	if conn == nil {
		return
	}
	defer conn.Close()
	if !destination.IsValid() {
		return
	}

	decision, reason := classifyFlow(N.NetworkTCP, source, destination)
	switch decision {
	case routeAround:
		if h.mgr.routeAround(destination.Addr, reason) {
			// Drop this attempt; the client's retry leaves via the physical NIC.
			return
		}
		fallthrough
	case relayDirect:
		h.logFlow(N.NetworkTCP, source, destination, reason)
		server, err := h.dialBypass(N.NetworkTCP, source, destination)
		if err != nil {
			h.mgr.logger.WithError(err).WithField("dst", destination.String()).Debug("bypass dial failed")
			return
		}
		defer server.Close()
		pipe(conn, server)
		return
	}

	addr := destination.String()
	dialStart := time.Now()
	server, err := h.mgr.dialServer(N.NetworkTCP, addr, dialTimeout)
	if err != nil {
		h.mgr.logger.WithError(err).WithField("dst", h.describe(destination)).Debug("dial failed")
		return
	}
	defer server.Close()

	if !h.mgr.targetPorts[destination.Port] {
		pipe(conn, server)
		return
	}
	h.injectAndForward(conn, server, destination, dialStart)
}

// injectAndForward sends fake ClientHellos with a low TTL (they reach the DPI
// box but expire before the server), then forwards the real handshake.
func (h *handler) injectAndForward(app, server net.Conn, destination M.Socksaddr, dialStart time.Time) {
	// Seq/ack lookup runs while we wait for the app's first bytes.
	type seqAck struct{ seq, ack uint32 }
	seqCh := make(chan seqAck, 1)
	go func() {
		s, a := seqtrack.GetSeqAck(server, dialStart)
		seqCh <- seqAck{s, a}
	}()

	first := buf.Get(16384)
	defer buf.Put(first)
	app.SetReadDeadline(time.Now().Add(helloReadTimeout))
	n, err := app.Read(first)
	app.SetReadDeadline(time.Time{})
	if n == 0 {
		if err != nil && isTimeout(err) {
			// Server-speaks-first or idle preconnect: nothing to disguise.
			pipe(app, server)
		}
		return
	}
	hello := first[:n]

	local, ok1 := server.LocalAddr().(*net.TCPAddr)
	remote, ok2 := server.RemoteAddr().(*net.TCPAddr)
	sa := <-seqCh
	if ok1 && ok2 {
		sni := fake.ParseSNI(hello)
		if sni != "" && isDiscordHost(sni) {
			if a, ok := netip.AddrFromSlice(remote.IP); ok {
				noteDiscordIP(a)
			}
		}
		info := rawsock.ConnInfo{
			SrcIP: local.IP, DstIP: remote.IP,
			SrcPort: uint16(local.Port), DstPort: uint16(remote.Port),
			Seq: sa.seq, Ack: sa.ack,
		}
		var sendErr error
		for i := 0; i < fakeCount && sendErr == nil; i++ {
			sendErr = h.mgr.rawSock.SendFake(info, fake.TLSClientHello, h.mgr.cfg.FakeTTL)
		}
		entry := h.mgr.logger.WithFields(logrus.Fields{
			"dst": h.describeSNI(destination, sni), "seq": sa.seq, "ttl": h.mgr.cfg.FakeTTL,
		})
		if sendErr != nil {
			entry.WithError(sendErr).Warn("fake injection failed")
		} else {
			entry.Debug("fake ClientHellos injected")
		}
		// Let the fakes reach the DPI box before the real ClientHello.
		time.Sleep(2 * time.Millisecond)
	}

	if _, err := server.Write(hello); err != nil {
		return
	}
	pipe(app, server)
}

func (h *handler) NewPacketConnectionEx(ctx context.Context, conn N.PacketConn, source, destination M.Socksaddr, onClose N.CloseHandlerFunc) {
	if onClose != nil {
		defer onClose(nil)
	}
	if conn == nil {
		return
	}
	defer conn.Close()
	if !destination.IsValid() {
		return
	}

	decision, reason := classifyFlow(N.NetworkUDP, source, destination)
	switch decision {
	case routeAround:
		if h.mgr.routeAround(destination.Addr, reason) {
			return
		}
		fallthrough
	case relayDirect:
		h.logFlow(N.NetworkUDP, source, destination, reason)
		real, err := h.dialBypass(N.NetworkUDP, source, destination)
		if err != nil {
			if source.Port > 0 {
				h.mgr.logger.WithError(err).WithField("dst", destination.String()).Debug("bypass dial failed — using pcap relay")
				h.relayUDPPcap(conn, source, destination)
			}
			return
		}
		defer real.Close()
		relayUDP(conn, real, destination)
		return
	}

	real, err := h.mgr.dialServer(N.NetworkUDP, destination.String(), dialTimeout)
	if err != nil {
		return
	}
	defer real.Close()
	relayUDP(conn, real, destination)
}

func (h *handler) logFlow(network string, source, destination M.Socksaddr, reason string) {
	if !h.mgr.logger.IsLevelEnabled(logrus.DebugLevel) {
		return
	}
	h.mgr.logger.WithFields(logrus.Fields{
		"proto": network, "src": source.String(), "dst": destination.String(), "reason": reason,
	}).Debug("tunnel bypass relay")
}

// dialBypass dials through the physical NIC, reusing the app's source port
// when possible (some game servers expect it), else any port.
func (h *handler) dialBypass(network string, source, destination M.Socksaddr) (net.Conn, error) {
	dialer := net.Dialer{Timeout: dialTimeout, Control: h.mgr.bindControl}
	if source.Port > 0 {
		d := dialer
		switch network {
		case N.NetworkTCP:
			d.LocalAddr = &net.TCPAddr{Port: int(source.Port)}
		case N.NetworkUDP:
			d.LocalAddr = &net.UDPAddr{Port: int(source.Port)}
		}
		if c, err := d.Dial(network, destination.String()); err == nil || network == N.NetworkUDP {
			return c, err
		}
	}
	return dialer.Dial(network, destination.String())
}

// relayUDPPcap relays a UDP flow whose source port is held by the game
// itself: outbound datagrams are injected raw, inbound ones are captured.
func (h *handler) relayUDPPcap(tunConn N.PacketConn, source, destination M.Socksaddr) {
	localIP := h.mgr.phys.IP
	if localIP == nil {
		return
	}
	stop, err := h.mgr.rawSock.MonitorUDPInbound(localIP, source.Port, func(srcIP net.IP, srcPort uint16, payload []byte) {
		addr, ok := netip.AddrFromSlice(srcIP.To4())
		if !ok {
			return
		}
		_ = tunConn.WritePacket(buf.As(payload), M.SocksaddrFrom(addr, srcPort))
	})
	if err != nil {
		h.mgr.logger.WithError(err).Warn("pcap UDP inbound monitor failed")
		return
	}
	defer stop()

	dstIP := destination.Addr.AsSlice()
	for {
		b := buf.NewPacket()
		tunConn.SetReadDeadline(time.Now().Add(udpIdleTimeout))
		if _, err := tunConn.ReadPacket(b); err != nil {
			b.Release()
			return
		}
		err := h.mgr.rawSock.SendUDP(rawsock.ConnInfo{
			SrcIP: localIP, DstIP: dstIP, SrcPort: source.Port, DstPort: destination.Port,
		}, b.Bytes())
		b.Release()
		if err != nil {
			h.mgr.logger.WithError(err).Debug("pcap UDP inject failed")
		}
	}
}

// relayUDP copies datagrams both ways until either side is idle for
// udpIdleTimeout or fails; both sides are torn down together.
func relayUDP(tunConn N.PacketConn, real net.Conn, destination M.Socksaddr) {
	var once sync.Once
	closeBoth := func() {
		once.Do(func() {
			now := time.Now()
			real.SetDeadline(now)
			tunConn.SetReadDeadline(now)
		})
	}

	done := make(chan struct{})
	go func() {
		defer close(done)
		defer closeBoth()
		b := buf.Get(65535)
		defer buf.Put(b)
		for {
			real.SetReadDeadline(time.Now().Add(udpIdleTimeout))
			n, err := real.Read(b)
			if err != nil {
				return
			}
			if err := tunConn.WritePacket(buf.As(b[:n]), destination); err != nil {
				return
			}
		}
	}()

	for {
		b := buf.NewPacket()
		tunConn.SetReadDeadline(time.Now().Add(udpIdleTimeout))
		_, err := tunConn.ReadPacket(b)
		if err != nil {
			b.Release()
			break
		}
		_, err = real.Write(b.Bytes())
		b.Release()
		if err != nil {
			break
		}
	}
	closeBoth()
	<-done
}

func (h *handler) describe(destination M.Socksaddr) string {
	if dns := gecitdns.GetDNSServer(); dns != nil {
		if names := dns.DomainsForIP(destination.Addr.Unmap().String()); len(names) > 0 {
			return names[len(names)-1] + ":" + strconv.Itoa(int(destination.Port))
		}
	}
	return destination.String()
}

func (h *handler) describeSNI(destination M.Socksaddr, sni string) string {
	if sni != "" {
		return sni + ":" + strconv.Itoa(int(destination.Port))
	}
	return h.describe(destination)
}

func isTimeout(err error) bool {
	var ne net.Error
	return errors.Is(err, os.ErrDeadlineExceeded) || (errors.As(err, &ne) && ne.Timeout())
}

// pipe copies both directions, propagating half-close so request/response
// protocols that shut down their write side keep working.
//
// Idleness is judged for the connection as a whole: push channels (WhatsApp,
// Discord gateway, notifications) send mostly one way for long stretches, and
// cutting them when one direction goes quiet delays messages until the app
// notices and reconnects. Dead servers are still detected by TCP keepalive on
// the outbound socket.
func pipe(a, b net.Conn) {
	var (
		wg       sync.WaitGroup
		lastSeen atomic.Int64
		closed   atomic.Bool
	)
	lastSeen.Store(time.Now().UnixNano())
	wg.Add(2)
	teardown := func() {
		closed.Store(true)
		now := time.Now()
		a.SetDeadline(now)
		b.SetDeadline(now)
	}
	cp := func(dst, src net.Conn) {
		defer wg.Done()
		buffer := buf.Get(32 * 1024)
		defer buf.Put(buffer)
		for {
			readStart := time.Now()
			src.SetReadDeadline(readStart.Add(pipeIdleCheck))
			n, err := src.Read(buffer)
			if n > 0 {
				lastSeen.Store(time.Now().UnixNano())
				if _, wErr := dst.Write(buffer[:n]); wErr != nil {
					break
				}
			}
			if err != nil {
				// Only a read that actually sat out our deadline means "quiet".
				// ETIMEDOUT from a failed handshake or keepalive also reports
				// Timeout(), but comes back immediately on every call —
				// retrying it would spin a core for tcpIdleTimeout.
				waited := time.Since(readStart) >= pipeIdleCheck/2
				if waited && isTimeout(err) && !closed.Load() &&
					time.Since(time.Unix(0, lastSeen.Load())) < tcpIdleTimeout {
					continue // this direction is quiet, the connection is not
				}
				if err == io.EOF {
					if cw, ok := dst.(interface{ CloseWrite() error }); ok && cw.CloseWrite() == nil {
						return
					}
				}
				break
			}
		}
		// Error or idle: tear down both directions.
		teardown()
	}
	go cp(b, a)
	go cp(a, b)
	wg.Wait()
}
