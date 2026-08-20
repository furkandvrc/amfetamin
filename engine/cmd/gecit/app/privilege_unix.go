//go:build !windows

package app

import (
	"fmt"
	"os"

	"github.com/boratanrikulu/gecit/pkg/brand"
)

func checkPrivileges() error {
	if os.Geteuid() != 0 {
		return fmt.Errorf("%s requires root privileges — run with sudo", brand.EngineName)
	}
	return nil
}
