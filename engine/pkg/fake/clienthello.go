package fake

// TLSClientHello is a minimal TLS ClientHello with SNI "www.google.com".
// DPI processes this fake and records google.com as the SNI.
// The real ClientHello follows — DPI is already desynchronized.
var TLSClientHello = func() []byte {
	sni := []byte("www.google.com")
	sniLen := len(sni)

	sniExt := []byte{0x00, 0x00} // extension type: server_name
	sniPayload := []byte{0x00}   // name_type: host_name
	sniPayload = append(sniPayload, byte(sniLen>>8), byte(sniLen))
	sniPayload = append(sniPayload, sni...)

	sniListLen := len(sniPayload)
	sniExtData := []byte{byte(sniListLen >> 8), byte(sniListLen)}
	sniExtData = append(sniExtData, sniPayload...)

	sniExt = append(sniExt, byte(len(sniExtData)>>8), byte(len(sniExtData)))
	sniExt = append(sniExt, sniExtData...)

	body := []byte{0x03, 0x03}                  // client_version: TLS 1.2
	body = append(body, make([]byte, 32)...)    // random
	body = append(body, 0x00)                   // session_id_len
	body = append(body, 0x00, 0x02, 0x13, 0x01) // cipher suites
	body = append(body, 0x01, 0x00)             // compression
	body = append(body, byte(len(sniExt)>>8), byte(len(sniExt)))
	body = append(body, sniExt...)

	handshake := []byte{0x01, 0x00, byte(len(body) >> 8), byte(len(body))}
	handshake = append(handshake, body...)

	record := []byte{0x16, 0x03, 0x01, byte(len(handshake) >> 8), byte(len(handshake))}
	record = append(record, handshake...)

	return record
}()
