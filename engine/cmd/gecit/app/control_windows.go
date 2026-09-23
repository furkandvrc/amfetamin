package app

import (
	"errors"
	"fmt"

	"github.com/spf13/cobra"
	"golang.org/x/sys/windows"
)

// The launcher stops the engine by signalling a named event. Killing the
// process would skip DNS restore and route cleanup, and Windows has no
// SIGTERM for a windowless process.
const (
	stopEventName     = `Global\AmfetaminEngineStop`
	instanceMutexName = `Global\AmfetaminEngine`
)

func stopRequests() <-chan struct{} {
	ch := make(chan struct{})
	name, _ := windows.UTF16PtrFromString(stopEventName)
	ev, err := windows.CreateEvent(nil, 0, 0, name)
	if err != nil {
		return ch
	}
	// Clear a stale signal left from a previous stop request.
	windows.ResetEvent(ev)
	go func() {
		windows.WaitForSingleObject(ev, windows.INFINITE)
		close(ch)
	}()
	return ch
}

func acquireInstanceLock() (func(), error) {
	name, _ := windows.UTF16PtrFromString(instanceMutexName)
	h, err := windows.CreateMutex(nil, false, name)
	if err != nil {
		if errors.Is(err, windows.ERROR_ALREADY_EXISTS) {
			if h != 0 {
				windows.CloseHandle(h)
			}
			return nil, fmt.Errorf("another engine instance is already running")
		}
		return nil, fmt.Errorf("instance lock: %w", err)
	}
	return func() { windows.CloseHandle(h) }, nil
}

var stopCmd = &cobra.Command{
	Use:   "stop",
	Short: "Ask a running engine to shut down cleanly",
	RunE: func(cmd *cobra.Command, args []string) error {
		name, _ := windows.UTF16PtrFromString(stopEventName)
		ev, err := windows.OpenEvent(windows.EVENT_MODIFY_STATE, false, name)
		if err != nil {
			fmt.Println("engine is not running")
			return nil
		}
		defer windows.CloseHandle(ev)
		return windows.SetEvent(ev)
	},
}

func init() { rootCmd.AddCommand(stopCmd) }
