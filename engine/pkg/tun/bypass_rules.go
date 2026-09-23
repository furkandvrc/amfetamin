//go:build (darwin || windows) && with_gvisor

package tun

import (
	"fmt"
	"strconv"
	"strings"
	"sync/atomic"

	N "github.com/sagernet/sing/common/network"
)

// AutoUDPSpec is the special bypass rule that sends every UDP flow that
// doesn't need DPI evasion (i.e. not DNS/web/Discord) straight out of the
// physical NIC. It keeps game traffic out of the userspace stack entirely.
const AutoUDPSpec = "udp:auto"

type bypassRule struct {
	tcp   bool
	udp   bool
	start uint16
	end   uint16
	label string
}

type ruleSet struct {
	rules   []bypassRule
	autoUDP bool
}

var activeRules atomic.Pointer[ruleSet]

// SetBypassRules replaces the active port rules. Invalid specs are returned
// so the caller can log them; valid ones are still applied.
func SetBypassRules(specs []string) []error {
	rs := &ruleSet{}
	var errs []error
	for _, spec := range specs {
		if strings.EqualFold(strings.TrimSpace(spec), AutoUDPSpec) {
			rs.autoUDP = true
			continue
		}
		rules, err := parseBypassRuleSpec(spec)
		if err != nil {
			errs = append(errs, err)
			continue
		}
		rs.rules = append(rs.rules, rules...)
	}
	activeRules.Store(rs)
	return errs
}

func currentRules() *ruleSet {
	if rs := activeRules.Load(); rs != nil {
		return rs
	}
	return &ruleSet{}
}

func parseBypassRuleSpec(spec string) ([]bypassRule, error) {
	spec = strings.TrimSpace(spec)
	if spec == "" {
		return nil, fmt.Errorf("empty bypass rule")
	}

	tcp, udp := true, true
	rest := spec
	if proto, ports, ok := strings.Cut(spec, ":"); ok {
		switch strings.ToLower(strings.TrimSpace(proto)) {
		case "tcp":
			tcp, udp = true, false
		case "udp":
			tcp, udp = false, true
		case "both", "any":
		default:
			return nil, fmt.Errorf("unknown protocol in %q", spec)
		}
		rest = ports
	}

	start, end, err := parsePortRange(strings.TrimSpace(rest))
	if err != nil {
		return nil, fmt.Errorf("%q: %w", spec, err)
	}
	return []bypassRule{{tcp: tcp, udp: udp, start: start, end: end, label: spec}}, nil
}

func parsePortRange(s string) (start, end uint16, err error) {
	if s == "" {
		return 0, 0, fmt.Errorf("empty port")
	}
	if lo, hi, ok := strings.Cut(s, "-"); ok {
		if start, err = parsePort(lo); err != nil {
			return 0, 0, err
		}
		if end, err = parsePort(hi); err != nil {
			return 0, 0, err
		}
		if start > end {
			return 0, 0, fmt.Errorf("invalid port range %q", s)
		}
		return start, end, nil
	}
	start, err = parsePort(s)
	return start, start, err
}

func parsePort(s string) (uint16, error) {
	n, err := strconv.ParseUint(strings.TrimSpace(s), 10, 16)
	if err != nil || n == 0 {
		return 0, fmt.Errorf("invalid port %q", s)
	}
	return uint16(n), nil
}

func matchConfiguredBypass(network string, port uint16) (bool, string) {
	for _, r := range currentRules().rules {
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
