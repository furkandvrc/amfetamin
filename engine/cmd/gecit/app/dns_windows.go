package app

func stopSystemDNS()   {}
func resumeSystemDNS() {}

// dnsTarget: netsh takes the interface's friendly name directly.
func dnsTarget(iface string) string { return iface }
