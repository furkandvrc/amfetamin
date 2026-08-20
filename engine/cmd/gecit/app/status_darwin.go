package app

import (
	"fmt"
	"os"
)

func printPlatformStatus() {
	fmt.Printf("  engine:     tun\n")

	if os.Geteuid() != 0 {
		fmt.Printf("  (run with sudo for accurate capability detection)\n")
		return
	}

	fmt.Printf("  raw socket: available\n")
}
