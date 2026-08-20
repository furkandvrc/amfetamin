package app

import (
	"fmt"
	"runtime"

	"github.com/spf13/cobra"
)

var statusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show gecit status and system capabilities",
	RunE:  showStatus,
}

func init() {
	rootCmd.AddCommand(statusCmd)
}

func showStatus(cmd *cobra.Command, args []string) error {
	fmt.Printf("gecit status\n")
	fmt.Printf("  platform: %s/%s\n", runtime.GOOS, runtime.GOARCH)
	printPlatformStatus()
	return nil
}
