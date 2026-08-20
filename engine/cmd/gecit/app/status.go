package app

import (
	"fmt"
	"runtime"

	"github.com/boratanrikulu/gecit/pkg/brand"
	"github.com/spf13/cobra"
)

var statusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show " + brand.ProductName + " engine status and system capabilities",
	RunE:  showStatus,
}

func init() {
	rootCmd.AddCommand(statusCmd)
}

func showStatus(cmd *cobra.Command, args []string) error {
	fmt.Printf("%s engine status\n", brand.ProductName)
	fmt.Printf("  platform: %s/%s\n", runtime.GOOS, runtime.GOARCH)
	printPlatformStatus()
	return nil
}
