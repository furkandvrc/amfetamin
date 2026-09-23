//go:build !windows

package app

// Unix platforms stop the engine with SIGTERM/SIGINT; the PID file / launchd
// already prevent duplicate instances.
func stopRequests() <-chan struct{} { return make(chan struct{}) }

func acquireInstanceLock() (func(), error) { return func() {}, nil }
