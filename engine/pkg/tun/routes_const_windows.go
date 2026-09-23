//go:build windows && with_gvisor

package tun

// Windows uses explicit host routes via the physical gateway instead.
const routeAroundViaTunOptions = false
