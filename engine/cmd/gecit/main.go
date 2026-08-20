package main

import (
	"os"

	"github.com/boratanrikulu/gecit/cmd/gecit/app"
)

func main() {
	if err := app.Execute(); err != nil {
		os.Exit(1)
	}
}
