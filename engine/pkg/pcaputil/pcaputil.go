//go:build darwin || windows

// Package pcaputil holds the pcap helpers shared by the capture and rawsock
// packages on macOS (libpcap) and Windows (Npcap, loaded at runtime).
package pcaputil

import (
	"fmt"
	"net"
	"time"

	"github.com/google/gopacket/pcap"
)

// OpenLive opens a capture handle in immediate mode.
//
// pcap.OpenLive buffers packets until the read timeout expires, which on
// Npcap adds up to `timeout` of latency to every captured packet. That
// latency is paid by every TLS handshake (seq/ack tracking) and every
// relayed game packet, so immediate delivery is mandatory here. The timeout
// only bounds how long a blocking read waits when no packets arrive, so
// readers can notice shutdown.
func OpenLive(device string, snaplen int, timeout time.Duration) (*pcap.Handle, error) {
	inactive, err := pcap.NewInactiveHandle(device)
	if err != nil {
		return nil, err
	}
	defer inactive.CleanUp()

	if err := inactive.SetSnapLen(snaplen); err != nil {
		return nil, fmt.Errorf("snaplen: %w", err)
	}
	if err := inactive.SetPromisc(false); err != nil {
		return nil, fmt.Errorf("promisc: %w", err)
	}
	if err := inactive.SetTimeout(timeout); err != nil {
		return nil, fmt.Errorf("timeout: %w", err)
	}
	// Older libpcap/Npcap builds lack immediate mode; fall back to the
	// timeout-bounded behaviour rather than failing outright.
	_ = inactive.SetImmediateMode(true)

	return inactive.Activate()
}

// DeviceForInterface maps an OS interface name to the pcap device name.
// On macOS they are identical; on Windows the friendly name ("Wi-Fi") has to
// be matched to \Device\NPF_{GUID} through the interface addresses.
func DeviceForInterface(name string) (string, error) {
	iface, err := net.InterfaceByName(name)
	if err != nil {
		return "", fmt.Errorf("interface %q: %w", name, err)
	}
	addrs, err := iface.Addrs()
	if err != nil || len(addrs) == 0 {
		return "", fmt.Errorf("no addresses on %q", name)
	}
	ips := make(map[string]bool, len(addrs))
	for _, a := range addrs {
		if ipNet, ok := a.(*net.IPNet); ok {
			ips[ipNet.IP.String()] = true
		}
	}

	devs, err := pcap.FindAllDevs()
	if err != nil {
		return "", fmt.Errorf("pcap find devices: %w (is Npcap installed?)", err)
	}
	for _, dev := range devs {
		if dev.Name == name {
			return dev.Name, nil
		}
		for _, addr := range dev.Addresses {
			if ips[addr.IP.String()] {
				return dev.Name, nil
			}
		}
	}
	return "", fmt.Errorf("no pcap device found for %q", name)
}
