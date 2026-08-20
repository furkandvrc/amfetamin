//go:build (darwin || windows) && with_gvisor

package tun

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"sync"
	"time"

	gecitdns "github.com/boratanrikulu/gecit/pkg/dns"
	"github.com/boratanrikulu/gecit/pkg/fake"
	"github.com/boratanrikulu/gecit/pkg/seqtrack"
	"github.com/boratanrikulu/gecit/pkg/rawsock"
	singtun "github.com/sagernet/sing-tun"
	"github.com/sagernet/sing/common/buf"
	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
	"github.com/sirupsen/logrus"
)

type handler struct {
	mgr *Manager
}

func (h *handler) PrepareConnection(
	network string, source M.Socksaddr, destination M.Socksaddr,
	_ singtun.DirectRouteContext, _ time.Duration,
) (singtun.DirectRouteDestination, error) {
	if bypass, reason := tunnelBypassReason(network, source, destination); bypass {
		h.mgr.logger.WithFields(logrus.Fields{
			"proto":  network,
			"src":    source.String(),
			"dst":    destination.String(),
			"action": "bypass",
			"reason": reason,
		}).Debug("tunnel bypass")
	}
	// gvisor stack treats any PrepareConnection error as drop/reject (ErrBypass only
	// works on Linux nfqueue). Bypass traffic is relayed in New*ConnectionEx instead.
	return nil, nil
}

func (h *handler) NewConnectionEx(
	ctx context.Context,
	conn net.Conn,
	source M.Socksaddr,
	destination M.Socksaddr,
	onClose N.CloseHandlerFunc,
) {
	if onClose != nil {
		defer onClose(nil)
	}
	if conn == nil || !destination.IsValid() {
		return
	}
	defer conn.Close()

	if isDiscordDestination(destination) {
		noteDiscordIP(destination.Addr)
	}

	if bypass, reason := tunnelBypassReason(N.NetworkTCP, source, destination); bypass {
		h.logBypassRelay(N.NetworkTCP, source, destination, reason)
		serverConn, err := h.dialBypass(N.NetworkTCP, source, destination)
		if err != nil {
			h.mgr.logger.WithError(err).WithField("dst", destination.String()).Debug("bypass dial failed")
			return
		}
		defer serverConn.Close()
		pipe(conn, serverConn)
		return
	}

	dstPort := destination.Port
	addr := net.JoinHostPort(destination.AddrString(), fmt.Sprint(dstPort))
	dst := resolveDst(addr, destination.AddrString(), dstPort)

	serverConn, err := h.mgr.dialServer("tcp", addr, 5*time.Second)
	if err != nil {
		h.mgr.logger.WithError(err).WithField("dst", dst).Debug("dial failed")
		return
	}
	defer serverConn.Close()

	if !h.mgr.targetPorts[dstPort] {
		pipe(conn, serverConn)
		return
	}

	h.injectAndForward(conn, serverConn, dst)
}

func (h *handler) injectAndForward(appConn, serverConn net.Conn, dst string) {
	appConn.SetReadDeadline(time.Now().Add(5 * time.Second))
	clientHello := make([]byte, 16384)
	n, err := appConn.Read(clientHello)
	if err != nil {
		return
	}
	clientHello = clientHello[:n]
	appConn.SetReadDeadline(time.Time{})

	// Extract real destination from SNI — more reliable than DNS cache.
	if sni := fake.ParseSNI(clientHello); sni != "" {
		dst = fmt.Sprintf("%s:%d", sni, serverConn.RemoteAddr().(*net.TCPAddr).Port)
	}

	seq, ack := seqtrack.GetSeqAck(serverConn)

	serverTCP, ok1 := serverConn.LocalAddr().(*net.TCPAddr)
	remoteTCP, ok2 := serverConn.RemoteAddr().(*net.TCPAddr)
	if !ok1 || !ok2 {
		return
	}

	if sni := fake.ParseSNI(clientHello); sni != "" && isDiscordHost(sni) {
		if addr, ok := netip.AddrFromSlice(remoteTCP.IP); ok {
			noteDiscordIP(addr)
		}
	}

	connInfo := rawsock.ConnInfo{
		SrcIP: serverTCP.IP, DstIP: remoteTCP.IP,
		SrcPort: uint16(serverTCP.Port), DstPort: uint16(remoteTCP.Port),
		Seq: seq, Ack: ack,
	}

	for i := 0; i < 3; i++ {
		if err := h.mgr.rawSock.SendFake(connInfo, fake.TLSClientHello, h.mgr.cfg.FakeTTL); err != nil {
			h.mgr.logger.WithError(err).Warn("SendFake failed")
			break
		}
	}
	h.mgr.logger.WithFields(logrus.Fields{
		"dst": dst, "seq": seq, "ack": ack, "ttl": h.mgr.cfg.FakeTTL,
	}).Info("fake ClientHellos injected")

	// Let fakes reach DPI before the real ClientHello.
	time.Sleep(2 * time.Millisecond)

	if _, err := serverConn.Write(clientHello); err != nil {
		return
	}

	pipe(appConn, serverConn)
}

func (h *handler) NewPacketConnectionEx(
	ctx context.Context,
	conn N.PacketConn,
	source M.Socksaddr,
	destination M.Socksaddr,
	onClose N.CloseHandlerFunc,
) {
	if onClose != nil {
		defer onClose(nil)
	}
	if conn == nil || !destination.IsValid() {
		return
	}
	defer conn.Close()

	if bypass, reason := tunnelBypassReason(N.NetworkUDP, source, destination); bypass {
		h.logBypassRelay(N.NetworkUDP, source, destination, reason)
		realConn, err := h.dialBypass(N.NetworkUDP, source, destination)
		if err != nil {
			h.mgr.logger.WithError(err).WithField("dst", destination.String()).Debug("bypass dial failed")
			return
		}
		defer realConn.Close()
		h.relayUDP(conn, realConn, destination)
		return
	}

	addr := net.JoinHostPort(destination.AddrString(), fmt.Sprint(destination.Port))
	realConn, err := h.mgr.dialServer("udp", addr, 5*time.Second)
	if err != nil {
		return
	}
	defer realConn.Close()
	h.relayUDP(conn, realConn, destination)
}

func (h *handler) logBypassRelay(network string, source, destination M.Socksaddr, reason string) {
	h.mgr.logger.WithFields(logrus.Fields{
		"proto":  network,
		"src":    source.String(),
		"dst":    destination.String(),
		"action": "bypass relay",
		"reason": reason,
	}).Debug("tunnel bypass relay")
}

func (h *handler) dialBypass(network string, source, destination M.Socksaddr) (net.Conn, error) {
	addr := net.JoinHostPort(destination.AddrString(), fmt.Sprint(destination.Port))
	dialer := net.Dialer{
		Timeout: 5 * time.Second,
		Control: h.mgr.bindControl,
	}
	if source.Port > 0 {
		switch network {
		case N.NetworkTCP:
			dialer.LocalAddr = &net.TCPAddr{Port: int(source.Port)}
		case N.NetworkUDP:
			dialer.LocalAddr = &net.UDPAddr{Port: int(source.Port)}
		}
	}
	return dialer.Dial(network, addr)
}

func (h *handler) relayUDP(tunConn N.PacketConn, realConn net.Conn, destination M.Socksaddr) {
	done := make(chan struct{})
	go func() {
		defer close(done)
		rawBuf := make([]byte, 65535)
		for {
			realConn.SetReadDeadline(time.Now().Add(30 * time.Second))
			n, err := realConn.Read(rawBuf)
			if err != nil {
				return
			}
			if err := tunConn.WritePacket(buf.As(rawBuf[:n]), destination); err != nil {
				return
			}
		}
	}()

	for {
		b := buf.NewSize(65535)
		tunConn.SetReadDeadline(time.Now().Add(30 * time.Second))
		_, err := tunConn.ReadPacket(b)
		if err != nil {
			b.Release()
			break
		}
		_, err = realConn.Write(b.Bytes())
		b.Release()
		if err != nil {
			break
		}
	}
	<-done
}

func resolveDst(addr, ip string, port uint16) string {
	if dns := gecitdns.GetDNSServer(); dns != nil {
		if domain := dns.PopDomain(ip); domain != "" {
			return fmt.Sprintf("%s:%d", domain, port)
		}
	}
	return addr
}

const idleTimeout = 5 * time.Minute

func pipe(a, b net.Conn) {
	var wg sync.WaitGroup
	wg.Add(2)
	cp := func(dst, src net.Conn) {
		defer wg.Done()
		// Idle timeout: if no data flows for idleTimeout, close both sides.
		// Prevents goroutine/fd accumulation from idle connections.
		buf := make([]byte, 32*1024)
		for {
			src.SetReadDeadline(time.Now().Add(idleTimeout))
			n, err := src.Read(buf)
			if n > 0 {
				if _, wErr := dst.Write(buf[:n]); wErr != nil {
					break
				}
			}
			if err != nil {
				break
			}
		}
		a.SetDeadline(time.Now())
		b.SetDeadline(time.Now())
	}
	go cp(b, a)
	go cp(a, b)
	wg.Wait()
}
