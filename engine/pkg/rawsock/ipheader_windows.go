package rawsock

import "encoding/binary"

// Windows: same as Linux — network byte order.
func ipHeaderPutUint16(b []byte, v uint16) {
	binary.BigEndian.PutUint16(b, v)
}
