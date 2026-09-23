//go:build (darwin || windows) && with_gvisor

package tun

import (
	"io"
	"net"
	"testing"
	"time"
)

// tcpPair returns both ends of a real loopback TCP connection.
func tcpPair(t *testing.T) (net.Conn, net.Conn) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	accepted := make(chan net.Conn, 1)
	go func() {
		c, _ := ln.Accept()
		accepted <- c
	}()
	c, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	return c, <-accepted
}

// A push channel where only the server talks must survive quiet periods in
// the other direction (this used to cut WhatsApp's connection).
func TestPipeKeepsOneWayConnectionAlive(t *testing.T) {
	old := pipeIdleCheck
	pipeIdleCheck = 50 * time.Millisecond
	defer func() { pipeIdleCheck = old }()

	app, appSide := tcpPair(t)
	serverSide, server := tcpPair(t)
	go pipe(appSide, serverSide)
	defer app.Close()
	defer server.Close()

	for i := 0; i < 5; i++ {
		time.Sleep(120 * time.Millisecond) // > pipeIdleCheck, app never writes
		if _, err := server.Write([]byte("m")); err != nil {
			t.Fatalf("server write %d: %v", i, err)
		}
		app.SetReadDeadline(time.Now().Add(time.Second))
		b := make([]byte, 1)
		if _, err := io.ReadFull(app, b); err != nil {
			t.Fatalf("push %d not delivered: %v", i, err)
		}
	}
}

func TestPipeClosesWhenPeerCloses(t *testing.T) {
	app, appSide := tcpPair(t)
	serverSide, server := tcpPair(t)
	done := make(chan struct{})
	go func() { pipe(appSide, serverSide); close(done) }()

	server.Close()
	app.Close()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("pipe did not return after both peers closed")
	}
}
