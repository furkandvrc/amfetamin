//go:build (darwin || windows) && with_gvisor

package tun

// Game UDP ports/ranges bypass split tunnel (direct to NIC).
// Everything else uses TUN — Discord voice needs the same UDP proxy as pre-split full tunnel.
func isGameUDPBypassPort(port uint16) bool {
	switch {
	case port >= 27000 && port <= 27100: // Steam / Source
		return true
	case port >= 28015 && port <= 28050: // Rust
		return true
	case port == 7777 || port == 7778: // common dedicated servers
		return true
	case port == 3074: // Xbox Live
		return true
	case port >= 5000 && port <= 5500: // Riot (LoL client)
		return true
	case port == 8393: // Riot
		return true
	default:
		return false
	}
}

// Game TCP ports that must bypass split tunnel (non-443).
func isGameTCPBypassPort(port uint16) bool {
	return port >= 4950 && port <= 4955 // Warframe UPnP
}
