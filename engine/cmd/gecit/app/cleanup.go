package app

import (
	"fmt"

	"github.com/boratanrikulu/gecit/pkg/brand"
	"github.com/spf13/cobra"
)

var cleanupCmd = &cobra.Command{
	Use:   "cleanup",
	Short: "Restore system settings after a crash",
	Long:  `Removes stale routes and restores DNS settings left behind by an ` + brand.ProductName + ` engine crash or SIGKILL.`,
	RunE:  runCleanup,
}

func init() {
	rootCmd.AddCommand(cleanupCmd)
}

func runCleanup(cmd *cobra.Command, args []string) error {
	cleaned := platformCleanup()
	if cleaned {
		fmt.Println("cleanup complete — system settings restored")
	} else {
		fmt.Println("nothing to clean up")
	}
	return nil
}
