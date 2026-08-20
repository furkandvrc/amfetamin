#!/bin/bash
# gecit demo — shows DPI bypass in action
# Usage: sudo ./scripts/demo.sh [--ttl 12]

set -e

TTL=${2:-8}
GECIT="./bin/gecit-linux-arm64"
TARGET="https://discord.com"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}  gecit — DPI bypass via eBPF${NC}"
echo -e "  ─────────────────────────────"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "  ${RED}Run with sudo${NC}"
    exit 1
fi

# Check binary exists
if [ ! -f "$GECIT" ]; then
    echo -e "  ${RED}Binary not found. Run: lima make gecit-linux-arm64${NC}"
    exit 1
fi

# No manual DoH needed — gecit has built-in DoH DNS server.
echo ""

# Test WITHOUT gecit
echo -e "  ${BOLD}[1/3] Without gecit:${NC}"
printf "  "
RESULT=$(curl -so /dev/null -w "%{http_code}" --max-time 5  "$TARGET" 2>/dev/null || true)
if [ "$RESULT" = "000" ] || [ -z "$RESULT" ]; then
    echo -e "${RED}$TARGET → BLOCKED (timeout)${NC}"
else
    echo -e "$TARGET → HTTP $RESULT"
fi
echo ""

# Start gecit
echo -e "  ${BOLD}[2/3] Starting gecit (TTL=$TTL):${NC}"
$GECIT run --fake-ttl "$TTL" > /tmp/gecit-demo.log 2>&1 &
GECIT_PID=$!
sleep 2

# Show that it's running
FAKE_LINE=$(grep "fake ClientHello" /tmp/gecit-demo.log 2>/dev/null | tail -1)
if [ -n "$FAKE_LINE" ]; then
    echo -e "  ${GREEN}gecit active — fake injection running${NC}"
else
    echo -e "  ${GREEN}gecit active — waiting for connections${NC}"
fi
echo ""

# Test WITH gecit
echo -e "  ${BOLD}[3/3] With gecit:${NC}"
printf "  "
RESULT=$(curl -so /dev/null -w "%{http_code}" --max-time 10  "$TARGET" 2>/dev/null || true)
if [ "$RESULT" = "200" ] || [ "$RESULT" = "301" ] || [ "$RESULT" = "302" ]; then
    echo -e "${GREEN}$TARGET → HTTP $RESULT (DPI BYPASSED)${NC}"
elif [ "$RESULT" = "000" ] || [ -z "$RESULT" ]; then
    echo -e "${RED}$TARGET → BLOCKED (try different --ttl)${NC}"
else
    echo -e "$TARGET → HTTP $RESULT"
fi

# Show fake injection count
FAKE_COUNT=$(grep -c "fake ClientHello" /tmp/gecit-demo.log 2>/dev/null || echo "0")
echo -e "  ${CYAN}Fake packets injected: $FAKE_COUNT${NC}"

# Stop gecit
kill $GECIT_PID 2>/dev/null
wait $GECIT_PID 2>/dev/null

echo ""
echo -e "  ${BOLD}Method:${NC} DoH DNS + eBPF sock_ops → perf event → raw socket"
echo -e "  ${BOLD}Fake SNI:${NC} www.google.com (TTL=$TTL, expires before server)"
echo -e "  ${BOLD}Real SNI:${NC} discord.com (reaches server, DPI desynchronized)"
echo ""
