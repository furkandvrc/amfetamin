package fake

// ParseSNI extracts the Server Name Indication from a TLS ClientHello.
// Returns empty string if not a valid ClientHello or no SNI present.
func ParseSNI(data []byte) string {
	if len(data) < 5 || data[0] != 0x16 { // not a TLS handshake record
		return ""
	}
	recordLen := int(data[3])<<8 | int(data[4])
	if len(data) < 5+recordLen {
		return ""
	}
	hs := data[5 : 5+recordLen]

	if len(hs) < 4 || hs[0] != 0x01 { // not ClientHello
		return ""
	}
	hsLen := int(hs[1])<<16 | int(hs[2])<<8 | int(hs[3])
	if len(hs) < 4+hsLen {
		return ""
	}
	body := hs[4 : 4+hsLen]

	if len(body) < 34 {
		return ""
	}
	pos := 34 // skip version(2) + random(32)

	if pos >= len(body) {
		return ""
	}
	pos += 1 + int(body[pos]) // skip session ID

	if pos+2 > len(body) {
		return ""
	}
	csLen := int(body[pos])<<8 | int(body[pos+1])
	pos += 2 + csLen

	if pos >= len(body) {
		return ""
	}
	pos += 1 + int(body[pos]) // skip compression methods

	if pos+2 > len(body) {
		return ""
	}
	extLen := int(body[pos])<<8 | int(body[pos+1])
	pos += 2
	if pos+extLen > len(body) {
		return ""
	}
	exts := body[pos : pos+extLen]

	for len(exts) >= 4 {
		extType := int(exts[0])<<8 | int(exts[1])
		extDataLen := int(exts[2])<<8 | int(exts[3])
		if 4+extDataLen > len(exts) {
			break
		}
		if extType == 0 { // SNI extension
			return parseSNIExtension(exts[4 : 4+extDataLen])
		}
		exts = exts[4+extDataLen:]
	}
	return ""
}

func parseSNIExtension(data []byte) string {
	if len(data) < 2 {
		return ""
	}
	listLen := int(data[0])<<8 | int(data[1])
	if 2+listLen > len(data) {
		return ""
	}
	entries := data[2 : 2+listLen]

	for len(entries) >= 3 {
		nameType := entries[0]
		nameLen := int(entries[1])<<8 | int(entries[2])
		if 3+nameLen > len(entries) {
			break
		}
		if nameType == 0 { // host_name
			return string(entries[3 : 3+nameLen])
		}
		entries = entries[3+nameLen:]
	}
	return ""
}
