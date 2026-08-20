//go:build !windows

package app

import (
	"fmt"
	"os"
)

func checkPrivileges() error {
	if os.Geteuid() != 0 {
		return fmt.Errorf("gecit requires root privileges — run with sudo")
	}
	return nil
}
