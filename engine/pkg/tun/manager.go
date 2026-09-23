//go:build (darwin || windows) && with_gvisor

package tun

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"sync"
	"time"

	gecitdns "github.com/boratanrikulu/gecit/pkg/dns"
	"github.com/boratanrikulu/gecit/pkg/netif"
	"github.com/boratanrikulu/gecit/pkg/rawsock"
	"github.com/boratanrikulu/gecit/pkg/seqtrack"
	"github.com/sagernet/sing-tun"
	"github.com/sagernet/sing/common/control"
	singlog "github.com/sagernet/sing/common/logger"
	"github.com/sirupsen/logrus"
)

const (
	tunName = "utun85"
	tunMTU  = 1420
)

var (
	tunPrefix  = netip.MustParsePrefix("10.0.85.1/30")
	tunGateway = netip.MustParseAddr("10.0.85.2")
)

type Config struct {
	Ports       []uint16
	FakeTTL     int
	Interface   string
	LANExclude  bool // keep RFC1918/multicast off the TUN (legacy --split-tunnel)
	BypassRules []string
}

type Manager struct {
	cfg         Config
	targetPorts map[uint16]bool
	logger      *logrus.Logger

	ctx    context.Context
	cancel context.CancelFunc

	phys           netif.Info
	tunDevice      tun.Tun
	stack          tun.Stack
	rawSock        rawsock.RawSocket
	ifaceFinder    control.InterfaceFinder
	bindControl    control.Func
	networkMonitor tun.NetworkUpdateMonitor
	ifaceMonitor   tun.DefaultInterfaceMonitor

	routesMu     sync.Mutex
	routedAround map[netip.Prefix]struct{}
	routeUpdate  *time.Timer // darwin: coalesced route rebuild
}

func NewManager(cfg Config, logger *logrus.Logger) *Manager {
	if cfg.FakeTTL <= 0 {
		cfg.FakeTTL = 8
	}
	if len(cfg.Ports) == 0 {
		cfg.Ports = []uint16{443}
	}
	ports := make(map[uint16]bool, len(cfg.Ports))
	for _, p := range cfg.Ports {
		ports[p] = true
	}
	return &Manager{
		cfg:          cfg,
		targetPorts:  ports,
		logger:       logger,
		routedAround: make(map[netip.Prefix]struct{}),
	}
}

// Physical resolves the uplink before anything else touches routing. It is
// safe to call before Start (the DoH client needs it early).
func (m *Manager) Physical() (netif.Info, error) {
	if m.phys.Name != "" {
		return m.phys, nil
	}
	info, err := netif.Default(m.cfg.Interface)
	if err != nil {
		return netif.Info{}, err
	}
	m.phys = info
	return info, nil
}

func (m *Manager) Start(ctx context.Context) (err error) {
	m.ctx, m.cancel = context.WithCancel(ctx)
	for _, e := range SetBypassRules(m.cfg.BypassRules) {
		m.logger.WithError(e).Warn("ignoring invalid bypass rule")
	}

	phys, err := m.Physical()
	if err != nil {
		return fmt.Errorf("detect network interface: %w", err)
	}
	m.logger.WithField("interface", phys.String()).Info("physical interface")

	// Undo partial setup on any failure below.
	defer func() {
		if err != nil {
			m.Stop()
		}
	}()

	if m.rawSock, err = rawsock.New(phys); err != nil {
		return fmt.Errorf("raw socket: %w", err)
	}

	if st, stErr := seqtrack.NewSeqTracker(phys.Name, m.cfg.Ports); stErr != nil {
		m.logger.WithError(stErr).Warn("seq tracker unavailable — fakes may be ignored by DPI")
	} else {
		seqtrack.SetSeqTracker(st)
	}

	if err = m.initNetworking(phys.Name); err != nil {
		return err
	}

	opts := m.tunOptions()
	if m.tunDevice, err = tun.New(opts); err != nil {
		return fmt.Errorf("create TUN: %w", err)
	}
	name, _ := m.tunDevice.Name()

	if m.stack, err = tun.NewStack("gvisor", tun.StackOptions{
		Context:                m.ctx,
		Tun:                    m.tunDevice,
		TunOptions:             opts,
		UDPTimeout:             60 * time.Second,
		Handler:                &handler{mgr: m},
		Logger:                 singlog.Logger(m.logger),
		ForwarderBindInterface: true,
		InterfaceFinder:        m.ifaceFinder,
	}); err != nil {
		return fmt.Errorf("create stack: %w", err)
	}
	if err = m.tunDevice.Start(); err != nil {
		return fmt.Errorf("start TUN: %w", err)
	}
	if err = m.stack.Start(); err != nil {
		return fmt.Errorf("start stack: %w", err)
	}

	rules := currentRules()
	m.logger.WithFields(logrus.Fields{
		"tun":          name,
		"ports":        m.cfg.Ports,
		"ttl":          m.cfg.FakeTTL,
		"bypass_rules": len(rules.rules),
		"auto_udp":     rules.autoUDP,
		"lan_exclude":  m.lanExclude(),
	}).Info("TUN engine active")
	return nil
}

// GameBypassMode reports whether any game bypass rule is configured.
func (m *Manager) GameBypassMode() bool {
	rs := currentRules()
	return len(rs.rules) > 0 || rs.autoUDP
}

func (m *Manager) lanExclude() bool { return m.cfg.LANExclude || m.GameBypassMode() }

func (m *Manager) Stop() error {
	m.logger.Info("stopping TUN engine")
	m.routesMu.Lock()
	if m.routeUpdate != nil {
		m.routeUpdate.Stop()
	}
	m.routesMu.Unlock()
	m.cleanupRoutesAround()

	if m.cancel != nil {
		m.cancel()
	}
	if m.stack != nil {
		m.stack.Close()
	}
	if m.tunDevice != nil {
		m.tunDevice.Close()
	}
	if m.ifaceMonitor != nil {
		m.ifaceMonitor.Close()
	}
	if m.networkMonitor != nil {
		m.networkMonitor.Close()
	}
	seqtrack.SetSeqTracker(nil)
	if m.rawSock != nil {
		m.rawSock.Close()
	}
	m.logger.Info("TUN engine stopped")
	return nil
}

func (m *Manager) dialServer(network, addr string, timeout time.Duration) (net.Conn, error) {
	dialer := net.Dialer{Timeout: timeout, Control: m.bindControl}
	return dialer.DialContext(m.ctx, network, addr)
}

// DialContext dials through the physical NIC, bypassing the TUN. Used by the
// DoH client, which starts before the TUN exists.
func (m *Manager) DialContext(ctx context.Context, network, addr string) (net.Conn, error) {
	ctrl := m.bindControl
	if ctrl == nil {
		phys, err := m.Physical()
		if err != nil {
			return nil, err
		}
		ctrl = control.Append(nil, control.BindToInterface(control.NewDefaultInterfaceFinder(), phys.Name, phys.Index))
	}
	return (&net.Dialer{Timeout: 5 * time.Second, Control: ctrl}).DialContext(ctx, network, addr)
}

func (m *Manager) initNetworking(physIface string) error {
	m.ifaceFinder = control.NewDefaultInterfaceFinder()
	m.bindControl = control.Append(nil, control.BindToInterface(m.ifaceFinder, physIface, -1))

	var err error
	if m.networkMonitor, err = tun.NewNetworkUpdateMonitor(singlog.Logger(m.logger)); err != nil {
		return fmt.Errorf("network monitor: %w", err)
	}
	if m.ifaceMonitor, err = tun.NewDefaultInterfaceMonitor(m.networkMonitor, singlog.Logger(m.logger), tun.DefaultInterfaceMonitorOptions{
		InterfaceFinder: m.ifaceFinder,
	}); err != nil {
		return fmt.Errorf("interface monitor: %w", err)
	}
	if err = m.networkMonitor.Start(); err != nil {
		return fmt.Errorf("start network monitor: %w", err)
	}
	if err = m.ifaceMonitor.Start(); err != nil {
		return fmt.Errorf("start interface monitor: %w", err)
	}
	return nil
}

func (m *Manager) tunOptions() tun.Options {
	opts := tun.Options{
		Name:             tunName,
		Inet4Address:     []netip.Prefix{tunPrefix},
		Inet4Gateway:     tunGateway,
		MTU:              tunMTU,
		AutoRoute:        true,
		StrictRoute:      false,
		InterfaceMonitor: m.ifaceMonitor,
		InterfaceFinder:  m.ifaceFinder,
		DNSServers:       []netip.Addr{netip.MustParseAddr(gecitdns.ActiveIP())},
	}
	var excludes []netip.Prefix
	if m.lanExclude() {
		excludes = append(excludes, lanRouteExcludes...)
	}
	if routeAroundViaTunOptions {
		excludes = append(excludes, m.routedAroundPrefixes()...)
	}
	opts.Inet4RouteExcludeAddress = excludes
	return opts
}
