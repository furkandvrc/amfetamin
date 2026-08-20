//go:build (darwin || windows) && with_gvisor

package tun

import (
	"fmt"
	"strconv"
	"strings"
	"sync"

	N "github.com/sagernet/sing/common/network"
)

type bypassRule struct {
	tcp   bool
	udp   bool
	start uint16
	end   uint16
	label string
}

var (
	bypassRulesMu sync.RWMutex
	bypassRules   []bypassRule
)

func SetBypassRules(specs []string) {
	parsed := make([]bypassRule, 0, len(specs))
	for _, spec := range specs {
		rules, err := parseBypassRuleSpec(spec)
		if err != nil {
			continue
		}
		parsed = append(parsed, rules...)
	}
	bypassRulesMu.Lock()
	bypassRules = parsed
	bypassRulesMu.Unlock()
}

func parseBypassRuleSpec(spec string) ([]bypassRule, error) {
	spec = strings.TrimSpace(spec)
	if spec == "" {
		return nil, fmt.Errorf("empty bypass rule")
	}

	tcp := true
	udp := true
	rest := spec
	if strings.Contains(spec, ":") {
		proto, ports, ok := strings.Cut(spec, ":")
		if !ok {
			return nil, fmt.Errorf("invalid bypass rule %q", spec)
		}
		switch strings.ToLower(strings.TrimSpace(proto)) {
		case "tcp":
			tcp, udp = true, false
		case "udp":
			tcp, udp = false, true
		case "both":
			tcp, udp = true, true
		default:
			return nil, fmt.Errorf("unknown protocol in %q", spec)
		}
		rest = ports
	}

	start, end, err := parsePortRange(strings.TrimSpace(rest))
	if err != nil {
		return nil, err
	}

	return []bypassRule{{
		tcp:   tcp,
		udp:   udp,
		start: start,
		end:   end,
		label: spec,
	}}, nil
}

func parsePortRange(s string) (start, end uint16, err error) {
	if s == "" {
		return 0, 0, fmt.Errorf("empty port")
	}
	if strings.Contains(s, "-") {
		parts := strings.SplitN(s, "-", 2)
		start, err = parsePort(parts[0])
		if err != nil {
			return 0, 0, err
		}
		end, err = parsePort(parts[1])
		if err != nil {
			return 0, 0, err
		}
		if start > end {
			return 0, 0, fmt.Errorf("invalid port range %q", s)
		}
		return start, end, nil
	}
	start, err = parsePort(s)
	if err != nil {
		return 0, 0, err
	}
	return start, start, nil
}

func parsePort(s string) (uint16, error) {
	s = strings.TrimSpace(s)
	n, err := strconv.ParseUint(s, 10, 16)
	if err != nil || n == 0 {
		return 0, fmt.Errorf("invalid port %q", s)
	}
	return uint16(n), nil
}

func matchConfiguredBypass(network string, port uint16) (bool, string) {
	bypassRulesMu.RLock()
	rules := bypassRules
	bypassRulesMu.RUnlock()

	for _, r := range rules {
		if network == N.NetworkUDP && !r.udp {
			continue
		}
		if network == N.NetworkTCP && !r.tcp {
			continue
		}
		if port >= r.start && port <= r.end {
			return true, r.label
		}
	}
	return false, ""
}
