package app

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/boratanrikulu/gecit/pkg/brand"
	"github.com/boratanrikulu/gecit/pkg/engine"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var runCmd = &cobra.Command{
	Use:   "run",
	Short: "Start the DPI bypass engine",
	RunE:  runEngine,
}

func init() {
	runCmd.Flags().Int("fake-ttl", 8, "TTL for fake packets (reaches DPI, not server)")
	runCmd.Flags().Bool("doh", true, "enable built-in DoH DNS resolver")
	runCmd.Flags().String("doh-upstream", "cloudflare", "DoH upstream: preset (cloudflare,google,quad9,nextdns,adguard) or URL")
	runCmd.Flags().Int("mss", 88, "TCP MSS for ClientHello fragmentation (Linux only)")
	runCmd.Flags().Int("restore-after-bytes", 600, "restore normal MSS after N bytes (Linux only)")
	runCmd.Flags().Int("restore-mss", 0, "restored MSS value, 0 = auto/1460 (Linux only)")
	runCmd.Flags().String("cgroup", "/sys/fs/cgroup", "cgroup v2 path (Linux only)")
	runCmd.Flags().BoolP("verbose", "v", false, "enable debug logging")
	runCmd.Flags().Bool("split-tunnel", false, "keep LAN/private ranges off the TUN")
	runCmd.Flags().StringArray("bypass-rule", nil, "bypass TUN for port/spec (e.g. udp:4950-4955, tcp:6695-6699, 27015, udp:auto)")
	runCmd.Flags().String("log-file", "", "write logs to this file (rotated at 5 MB) instead of stderr")
	runCmd.Flags().Bool("filter-aaaa", true, "answer AAAA queries empty so apps use IPv4 through the tunnel")

	viper.BindPFlag("verbose", runCmd.Flags().Lookup("verbose"))
	viper.BindPFlag("split_tunnel", runCmd.Flags().Lookup("split-tunnel"))
	viper.BindPFlag("bypass_rules", runCmd.Flags().Lookup("bypass-rule"))
	viper.BindPFlag("filter_aaaa", runCmd.Flags().Lookup("filter-aaaa"))
	viper.BindPFlag("log_file", runCmd.Flags().Lookup("log-file"))
	viper.BindPFlag("fake_ttl", runCmd.Flags().Lookup("fake-ttl"))
	viper.BindPFlag("doh_enabled", runCmd.Flags().Lookup("doh"))
	viper.BindPFlag("doh_upstream", runCmd.Flags().Lookup("doh-upstream"))
	viper.BindPFlag("mss", runCmd.Flags().Lookup("mss"))
	viper.BindPFlag("restore_after_bytes", runCmd.Flags().Lookup("restore-after-bytes"))
	viper.BindPFlag("restore_mss", runCmd.Flags().Lookup("restore-mss"))
	viper.BindPFlag("cgroup_path", runCmd.Flags().Lookup("cgroup"))

	rootCmd.AddCommand(runCmd)
}

func runEngine(cmd *cobra.Command, args []string) (err error) {
	if err := checkPrivileges(); err != nil {
		return err
	}

	logger := logrus.New()
	logger.SetFormatter(&logrus.TextFormatter{FullTimestamp: true})
	if viper.GetBool("verbose") {
		logger.SetLevel(logrus.DebugLevel)
	}
	if path := viper.GetString("log_file"); path != "" {
		f, err := openRotatingFile(path, 5<<20)
		if err != nil {
			return fmt.Errorf("open log file: %w", err)
		}
		logger.SetOutput(f)
		logger.SetFormatter(&logrus.TextFormatter{FullTimestamp: true, DisableColors: true})
		logrus.SetOutput(f)
	}
	defer func() {
		if err != nil {
			logger.WithError(err).Error("engine exited with error")
		}
	}()

	cfg := engine.Config{
		MSS:               viper.GetInt("mss"),
		RestoreMSS:        viper.GetInt("restore_mss"),
		RestoreAfterBytes: viper.GetInt("restore_after_bytes"),
		Ports:             toUint16Slice(viper.GetIntSlice("ports")),
		Interface:         viper.GetString("interface"),
		CgroupPath:        viper.GetString("cgroup_path"),
		FakeTTL:           viper.GetInt("fake_ttl"),
		DoHEnabled:        viper.GetBool("doh_enabled"),
		DoHUpstream:       viper.GetString("doh_upstream"),
		SplitTunnel:       viper.GetBool("split_tunnel"),
		BypassRules:       viper.GetStringSlice("bypass_rules"),
		FilterAAAA:        viper.GetBool("filter_aaaa"),
	}

	release, lockErr := acquireInstanceLock()
	if lockErr != nil {
		return lockErr
	}
	defer release()

	// Listen for stop requests before touching system settings so a stop
	// that arrives during startup still triggers a clean shutdown.
	stopCh := stopRequests()
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	eng, err := newPlatformEngine(cfg, logger)
	if err != nil {
		return err
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if err := eng.Start(ctx); err != nil {
		return fmt.Errorf("start: %w", err)
	}

	logger.WithField("mode", eng.Mode()).Info(brand.ProductName + " engine running (Ctrl+C to stop)")

	select {
	case <-sigCh:
	case <-stopCh:
	}

	logger.Info("shutting down...")
	return eng.Stop()
}

func toUint16Slice(ints []int) []uint16 {
	out := make([]uint16, 0, len(ints))
	for _, v := range ints {
		if v > 0 && v <= 65535 {
			out = append(out, uint16(v))
		}
	}
	return out
}
