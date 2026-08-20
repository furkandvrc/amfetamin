package rawsock

import "encoding/binary"

// macOS: IP total length and frag offset must be in host byte order (little-endian
// on arm64/amd64). This is a BSD quirk — the kernel byte-swaps these fields
// before sending. Passing them in network byte order causes "invalid argument".
func ipHeaderPutUint16(b []byte, v uint16) {
	binary.LittleEndian.PutUint16(b, v)
}
