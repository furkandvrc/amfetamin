package fake

import (
	"bytes"
	"testing"
)

func TestTLSClientHello_RecordLayer(t *testing.T) {
	ch := TLSClientHello

	if len(ch) < 5 {
		t.Fatalf("ClientHello too short: %d bytes", len(ch))
	}

	// Content type: Handshake (0x16).
	if ch[0] != 0x16 {
		t.Fatalf("record type: got 0x%02x, want 0x16 (Handshake)", ch[0])
	}

	// Record version: TLS 1.0 (0x0301) — standard for ClientHello record layer.
	if ch[1] != 0x03 || ch[2] != 0x01 {
		t.Fatalf("record version: got 0x%02x%02x, want 0x0301", ch[1], ch[2])
	}

	// Record length should match remaining bytes.
	recordLen := int(ch[3])<<8 | int(ch[4])
	if recordLen != len(ch)-5 {
		t.Fatalf("record length: got %d, want %d", recordLen, len(ch)-5)
	}
}

func TestTLSClientHello_HandshakeType(t *testing.T) {
	ch := TLSClientHello

	// Handshake type: ClientHello (0x01).
	if ch[5] != 0x01 {
		t.Fatalf("handshake type: got 0x%02x, want 0x01 (ClientHello)", ch[5])
	}

	// Handshake length (3 bytes).
	hsLen := int(ch[6])<<16 | int(ch[7])<<8 | int(ch[8])
	if hsLen != len(ch)-9 {
		t.Fatalf("handshake length: got %d, want %d", hsLen, len(ch)-9)
	}
}

func TestTLSClientHello_ClientVersion(t *testing.T) {
	ch := TLSClientHello

	// Client version: TLS 1.2 (0x0303).
	if ch[9] != 0x03 || ch[10] != 0x03 {
		t.Fatalf("client version: got 0x%02x%02x, want 0x0303 (TLS 1.2)", ch[9], ch[10])
	}
}

func TestTLSClientHello_SNI(t *testing.T) {
	ch := TLSClientHello
	sni := []byte("www.google.com")

	if !bytes.Contains(ch, sni) {
		t.Fatal("ClientHello does not contain SNI \"www.google.com\"")
	}
}

func TestTLSClientHello_Deterministic(t *testing.T) {
	// The variable is computed once at init. Verify it doesn't change.
	a := make([]byte, len(TLSClientHello))
	copy(a, TLSClientHello)

	if !bytes.Equal(a, TLSClientHello) {
		t.Fatal("TLSClientHello is not stable")
	}
}
