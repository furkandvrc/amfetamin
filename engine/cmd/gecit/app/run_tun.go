//go:build darwin || windows

package app

import (
	"context"

	gecitdns "github.com/boratanrikulu/gecit/pkg/dns"
	"github.com/boratanrikulu/gecit/pkg/engine"
	gecittun "github.com/boratanrikulu/gecit/pkg/tun"
	"github.com/sirupsen/logrus"
)

type tunEngine struct {
	mgr        *gecittun.Manager
	dns        *gecitdns.Server
	dohEnabled bool
	logger     *logrus.Logger
}

func newPlatformEngine(cfg engine.Config, logger *logrus.Logger) (engine.Engine, error) {
	upstream := cfg.DoHUpstream
	if upstream == "" {
		upstream = "cloudflare"
	}

	mgr := gecittun.NewManager(gecittun.Config{
		Ports:       cfg.Ports,
		FakeTTL:     cfg.FakeTTL,
		Interface:   cfg.Interface,
		LANExclude:  cfg.SplitTunnel,
		BypassRules: cfg.BypassRules,
	}, logger)

	e := &tunEngine{mgr: mgr, dohEnabled: cfg.DoHEnabled, logger: logger}
	if cfg.DoHEnabled {
		e.dns = gecitdns.NewServer(upstream, logger, mgr.DialContext, gecitdns.Options{FilterAAAA: cfg.FilterAAAA})
	}
	return e, nil
}

func (e *tunEngine) Start(ctx context.Context) error {
	// Resolve the uplink while the routing table is still untouched.
	phys, err := e.mgr.Physical()
	if err != nil {
		return err
	}

	if e.dohEnabled {
		stopSystemDNS()
		if err := e.dns.Start(); err != nil {
			resumeSystemDNS()
			return err
		}
		if err := gecitdns.SetSystemDNS(dnsTarget(phys.Name)); err != nil {
			e.dns.Stop()
			resumeSystemDNS()
			return err
		}
		e.logger.WithField("service", dnsTarget(phys.Name)).Info("encrypted DNS active")
	}

	if err := e.mgr.Start(ctx); err != nil {
		if e.dohEnabled {
			gecitdns.RestoreSystemDNS()
			e.dns.Stop()
			resumeSystemDNS()
		}
		return err
	}
	return nil
}

func (e *tunEngine) Stop() error {
	e.mgr.Stop()
	if e.dohEnabled {
		if err := gecitdns.RestoreSystemDNS(); err != nil {
			e.logger.WithError(err).Warn("failed to restore system DNS")
		}
		e.dns.Stop()
		resumeSystemDNS()
		e.logger.Info("system DNS restored")
	}
	return nil
}

func (e *tunEngine) Mode() string {
	if e.mgr.GameBypassMode() {
		return "tun+game"
	}
	return "tun"
}
