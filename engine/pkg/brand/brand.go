package brand

const (
	// EngineName is the CLI / binary product name shown to users.
	EngineName = "amfetamin-engine"
	// ProductName is the short name used in log lines.
	ProductName = "amfetamin"
)

// Version is set at build time: -ldflags "-X github.com/boratanrikulu/gecit/pkg/brand.Version=v0.2.0"
var Version = "dev"
