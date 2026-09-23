//go:build darwin || windows

// Package seqtrack learns the real TCP seq/ack of proxied connections from
// SYN-ACKs captured on the physical NIC, so injected fakes carry sequence
// numbers the DPI box accepts.
package seqtrack

import (
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/boratanrikulu/gecit/pkg/capture"
	"github.com/sirupsen/logrus"
)

const (
	// waitTimeout bounds how long a new connection waits for its SYN-ACK to
	// show up in the capture. With immediate-mode pcap this is normally <5ms.
	waitTimeout = 400 * time.Millisecond
	// eventTTL drops SYN-ACKs nobody asked for (connections made by other
	// apps, DoH, bypass relays) so the table can't grow without bound and a
	// reused local port never picks up a stale sequence number.
	eventTTL = 5 * time.Second
)

type entry struct {
	evt  capture.ConnectionEvent
	seen time.Time
}

type SeqTracker struct {
	detector capture.Detector

	mu      sync.Mutex
	events  map[uint16]entry
	waiters map[uint16]chan capture.ConnectionEvent
	done    chan struct{}
}

func NewSeqTracker(iface string, ports []uint16) (*SeqTracker, error) {
	det, err := capture.NewCapture(iface, ports)
	if err != nil {
		return nil, err
	}
	st := &SeqTracker{
		detector: det,
		events:   make(map[uint16]entry),
		waiters:  make(map[uint16]chan capture.ConnectionEvent),
		done:     make(chan struct{}),
	}
	if err := det.Start(st.onEvent); err != nil {
		det.Stop()
		return nil, err
	}
	go st.pruneLoop()
	return st, nil
}

func (st *SeqTracker) onEvent(evt capture.ConnectionEvent) {
	st.mu.Lock()
	defer st.mu.Unlock()
	if ch, ok := st.waiters[evt.SrcPort]; ok {
		delete(st.waiters, evt.SrcPort)
		ch <- evt // buffered, never blocks
		return
	}
	st.events[evt.SrcPort] = entry{evt: evt, seen: time.Now()}
}

func (st *SeqTracker) pruneLoop() {
	t := time.NewTicker(eventTTL)
	defer t.Stop()
	for {
		select {
		case <-st.done:
			return
		case now := <-t.C:
			st.mu.Lock()
			for port, e := range st.events {
				if now.Sub(e.seen) > eventTTL {
					delete(st.events, port)
				}
			}
			st.mu.Unlock()
		}
	}
}

// WaitForSeqAck returns the SYN-ACK data for localPort/remote, waiting up to
// timeout for the capture to deliver it.
func (st *SeqTracker) WaitForSeqAck(localPort uint16, remote net.IP, dialStart time.Time, timeout time.Duration) *capture.ConnectionEvent {
	st.mu.Lock()
	if e, ok := st.events[localPort]; ok {
		delete(st.events, localPort)
		if e.evt.DstIP.Equal(remote) && !e.seen.Before(dialStart.Add(-50*time.Millisecond)) {
			st.mu.Unlock()
			return &e.evt
		}
	}
	ch := make(chan capture.ConnectionEvent, 1)
	st.waiters[localPort] = ch
	st.mu.Unlock()

	timer := time.NewTimer(timeout)
	defer timer.Stop()
	for {
		select {
		case evt := <-ch:
			if evt.DstIP.Equal(remote) {
				return &evt
			}
			// SYN-ACK for a different flow that happened to reuse the port;
			// keep waiting for ours.
			st.mu.Lock()
			st.waiters[localPort] = ch
			st.mu.Unlock()
		case <-timer.C:
			st.mu.Lock()
			if st.waiters[localPort] == ch {
				delete(st.waiters, localPort)
			}
			st.mu.Unlock()
			select {
			case evt := <-ch:
				if evt.DstIP.Equal(remote) {
					return &evt
				}
			default:
			}
			return nil
		}
	}
}

func (st *SeqTracker) Stop() {
	select {
	case <-st.done:
		return
	default:
		close(st.done)
	}
	if st.detector != nil {
		st.detector.Stop()
	}
}

var global atomic.Pointer[SeqTracker]

// SetSeqTracker installs st as the process-wide tracker, stopping any
// previously installed one.
func SetSeqTracker(st *SeqTracker) {
	if old := global.Swap(st); old != nil && old != st {
		old.Stop()
	}
}

// GetSeqAck returns the real seq/ack for conn, or (1, 1) when unknown.
func GetSeqAck(conn net.Conn, dialStart time.Time) (seq, ack uint32) {
	st := global.Load()
	if st == nil {
		return 1, 1
	}
	local, ok1 := conn.LocalAddr().(*net.TCPAddr)
	remote, ok2 := conn.RemoteAddr().(*net.TCPAddr)
	if !ok1 || !ok2 {
		return 1, 1
	}
	evt := st.WaitForSeqAck(uint16(local.Port), remote.IP, dialStart, waitTimeout)
	if evt == nil {
		logrus.WithField("port", local.Port).Warn("seq/ack not captured — fake may be ignored by DPI")
		return 1, 1
	}
	return evt.Seq, evt.Ack
}
