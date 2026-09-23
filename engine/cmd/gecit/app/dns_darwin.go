package app

import gecitdns "github.com/boratanrikulu/gecit/pkg/dns"

func stopSystemDNS()   { gecitdns.StopMDNSResponder() }
func resumeSystemDNS() { gecitdns.ResumeMDNSResponder() }

// dnsTarget maps the physical interface to the macOS network service name
// networksetup expects ("en0" -> "Wi-Fi").
func dnsTarget(iface string) string {
	if svc := gecitdns.NetworkServiceForInterface(iface); svc != "" {
		return svc
	}
	return gecitdns.DetectActiveService()
}
