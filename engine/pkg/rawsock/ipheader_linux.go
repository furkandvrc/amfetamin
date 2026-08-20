package rawsock

import "encoding/binary"

// Linux: IP total length and frag offset are in network byte order (big-endian).
func ipHeaderPutUint16(b []byte, v uint16) {
	binary.BigEndian.PutUint16(b, v)
}
