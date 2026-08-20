package app

import "fmt"

func printPlatformStatus() {
	fmt.Printf("  engine:     tun (wintun)\n")

	if err := checkPrivileges(); err != nil {
		fmt.Printf("  (run as Administrator for accurate capability detection)\n")
		return
	}

	fmt.Printf("  wintun:     available\n")
}
