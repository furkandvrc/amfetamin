#!/bin/bash
# amfetamin macOS — core

set -euo pipefail

MACOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=i18n.sh
source "$MACOS_DIR/lib/i18n.sh"
# shellcheck source=logger.sh
source "$MACOS_DIR/lib/logger.sh"

real_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        id -un
    fi
}

real_home() {
    local u
    u="$(real_user)"
    eval echo "~$u"
}

USER_HOME="$(real_home)"
INSTALL_ROOT="${AMFETAMIN_INSTALL_ROOT:-}"
if [[ -z "$INSTALL_ROOT" && -f "/Library/Application Support/Amfetamin/install-root.conf" ]]; then
    INSTALL_ROOT="$(cat "/Library/Application Support/Amfetamin/install-root.conf")"
fi
INSTALL_ROOT="${INSTALL_ROOT:-$USER_HOME/Library/Application Support/Amfetamin}"
BIN_DIR="$INSTALL_ROOT/bin"
LOG_DIR="$INSTALL_ROOT/logs"
LIB_DIR="$INSTALL_ROOT/lib"
CONFIG_PATH="$INSTALL_ROOT/config.json"
ENGINE_BIN="$BIN_DIR/amfetamin-engine"
ENGINE_TAG_FILE="$BIN_DIR/engine-tag.txt"
LAUNCHD_LABEL="com.furkandvrc.amfetamin"
LAUNCHD_PLIST="/Library/LaunchDaemons/${LAUNCHD_LABEL}.plist"
PID_FILE="$INSTALL_ROOT/amfetamin.pid"

export AMFETAMIN_LOG_DIR="$LOG_DIR"
mkdir -p "$AMFETAMIN_LOG_DIR"

ensure_dirs() {
    mkdir -p "$INSTALL_ROOT" "$BIN_DIR" "$LOG_DIR" "$LIB_DIR"
}

project_root() {
    if [[ -n "${AMFETAMIN_ROOT:-}" && -d "$AMFETAMIN_ROOT" ]]; then
        echo "$AMFETAMIN_ROOT"
        return
    fi
    echo "$MACOS_DIR"
}

cfg_python() {
    python3 - "$@" <<'PY'
import json, os, sys
action = sys.argv[1]
root = os.environ.get("CFG_ROOT", "")
install = os.environ.get("CFG_INSTALL", "")
paths = [p for p in [install, os.path.join(root, "config.json")] if p and os.path.isfile(p)]
if not paths:
    sys.exit(2)
with open(paths[0]) as f:
    cfg = json.load(f)
if action == "get":
    key = sys.argv[2]
    val = cfg.get(key, "")
    if isinstance(val, bool):
        print("true" if val else "false")
    elif isinstance(val, list):
        print(",".join(str(x) for x in val))
    else:
        print(val)
elif action == "set":
    key, val = sys.argv[2], sys.argv[3]
    if val in ("true", "false"):
        cfg[key] = val == "true"
    elif val.isdigit():
        cfg[key] = int(val)
    else:
        cfg[key] = val
    for p in paths:
        with open(p, "w") as f:
            json.dump(cfg, f, indent=2)
            f.write("\n")
PY
}

cfg_get() {
    CFG_ROOT="$(project_root)" CFG_INSTALL="$CONFIG_PATH" cfg_python get "$1" 2>/dev/null \
        || CFG_ROOT="$(project_root)" CFG_INSTALL="" cfg_python get "$1"
}

cfg_set() {
    CFG_ROOT="$(project_root)" CFG_INSTALL="$CONFIG_PATH" cfg_python set "$1" "$2"
    local proot
    proot="$(project_root)"
    if [[ -f "$proot/config.json" && "$CONFIG_PATH" != "$proot/config.json" ]]; then
        cp "$proot/config.json" "$CONFIG_PATH" 2>/dev/null || true
    fi
}

is_root() { [[ "$(id -u)" -eq 0 ]]; }

require_root() {
    if ! is_root; then
        echo "$(msg admin_required "$*")" >&2
        exit 1
    fi
}

detect_arch_asset() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        arm64)  echo "$(cfg_get engineAssetArm64)" ;;
        x86_64) echo "$(cfg_get engineAssetAmd64)" ;;
        *) echo "$(msg unsupported_arch "$arch")" >&2; exit 1 ;;
    esac
}

download_file() {
    local url="$1"
    local dest="$2"
    log_info "Indiriliyor: $url"
    curl -fsSL "$url" -o "$dest"
}

install_engine_binary() {
    ensure_dirs
    local asset base tag url tmp
    asset="$(detect_arch_asset)"
    base="$(cfg_get engineReleaseBase)"
    tag="$(cfg_get engineTag)"
    tmp="$BIN_DIR/.download.tmp"

    url="$base/$tag/$asset"
    download_file "$url" "$tmp"

    chmod +x "$tmp"
    mv "$tmp" "$ENGINE_BIN"
    printf '%s\n' "$tag" > "$ENGINE_TAG_FILE"
    log_info "Motor kuruldu: $ENGINE_BIN ($tag)" audit
}

engine_needs_install() {
    local want=""
    want="$(cfg_get engineTag)"
    [[ -z "$want" ]] && return 0
    [[ ! -x "$ENGINE_BIN" ]] && return 0
    [[ ! -f "$ENGINE_TAG_FILE" ]] && return 0
    [[ "$(tr -d '[:space:]' < "$ENGINE_TAG_FILE")" != "$want" ]]
}

ensure_engine_binary() {
    if ! engine_needs_install; then
        return 0
    fi
    if is_engine_running; then
        stop_engine quiet || true
        sleep 1
    fi
    log_info "Motor guncelleniyor: $(cfg_get engineTag)" audit
    install_engine_binary
}

sync_to_install() {
    ensure_dirs
    local proot
    proot="$(project_root)"
    cp "$proot/config.json" "$CONFIG_PATH" 2>/dev/null || true
    cp -R "$proot/lib/"* "$LIB_DIR/" 2>/dev/null || true
    log_info "Dosyalar senkronize edildi"
}

is_engine_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    pgrep -f amfetamin-engine >/dev/null 2>&1
}

test_bypass_reachable() {
    local url="${1:-https://discord.com}"
    local timeout="${2:-15}"
    curl -fsSIL --max-time "$timeout" "$url" >/dev/null 2>&1 \
        || curl -fsSL --max-time "$timeout" "$url" >/dev/null 2>&1
}

auto_tune_ttl() {
    local test_url timeout candidates ttl best
    test_url="$(cfg_get autoTuneUrl)"
    timeout="$(cfg_get autoTuneTimeoutSec)"
    candidates="$(cfg_get fakeTtlCandidates)"
    best=""

    log_info "TTL otomatik ayar basladi ($test_url)" audit
    IFS=',' read -ra CANDS <<< "$candidates"
    for ttl in "${CANDS[@]}"; do
        log_info "TTL deneniyor: $ttl"
        stop_engine quiet || true
        sleep 1
        start_engine_hidden "$ttl" skip_warmup quiet || continue
        sleep 3
        if test_bypass_reachable "$test_url" "$timeout"; then
            best="$ttl"
            log_info "TTL $ttl calisti"
            break
        fi
    done

    if [[ -z "$best" ]]; then
        best="$(cfg_get fakeTtl)"
        [[ -z "$best" ]] && best=8
        stop_engine quiet || true
        start_engine_hidden "$best" skip_warmup quiet || true
    fi

    cfg_set fakeTtl "$best"
    cfg_set autoTuneDone true
    sync_to_install
    echo "$(msg ttl_set "$best")"
}

should_auto_tune() {
    [[ "$(cfg_get autoTuneTtl)" != "true" ]] && return 1
    [[ "$(cfg_get autoTuneDone)" == "true" ]] && return 1
    return 0
}

start_engine_hidden() {
    local ttl_override="${1:-0}"
    local skip_warmup="${2:-}"
    local quiet="${3:-}"
    require_root
    ensure_engine_binary

    if is_engine_running; then
        [[ "$ttl_override" -gt 0 ]] || {
            [[ "$quiet" != "quiet" ]] && echo "$(msg service_already_running)"
            return 0
        }
        stop_engine quiet || true
        sleep 1
    fi

    local cfg_ttl verbose engine_args
    cfg_ttl="$(cfg_get fakeTtl)"
    verbose="$(cfg_get engineVerbose)"
    [[ "$ttl_override" -gt 0 ]] && cfg_ttl="$ttl_override"
    engine_args=( run --doh-upstream "$(cfg_get dohUpstream)" )
    [[ -n "$cfg_ttl" && "$cfg_ttl" -gt 0 ]] && engine_args+=( --fake-ttl "$cfg_ttl" )
    [[ "$(cfg_get splitTunnel)" == "true" ]] && engine_args+=( --split-tunnel )
    [[ "$verbose" == "true" ]] && engine_args+=( -v )

    "$ENGINE_BIN" "${engine_args[@]}" >> "$LOG_DIR/engine.log" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2
    if is_engine_running; then
        log_info "Motor baslatildi PID=$(cat "$PID_FILE")" audit
        [[ "$skip_warmup" == "skip_warmup" ]] || engine_warmup
        [[ "$quiet" != "quiet" ]] && echo "$(msg service_started)"
        return 0
    fi
    log_error "$(msg engine_start_failed)"
    return 1
}

engine_warmup() {
    local urls=( "https://www.google.com/generate_204" "https://discord.com" )
    for url in "${urls[@]}"; do
        curl -fsSIL --max-time 6 "$url" >/dev/null 2>&1 || curl -fsSL --max-time 6 "$url" >/dev/null 2>&1 || true
    done
}

stop_engine() {
    local quiet="${1:-}"
    local was_running=0
    is_engine_running && was_running=1

    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]]; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
    pkill -f amfetamin-engine 2>/dev/null || true

    if [[ "$was_running" -eq 1 ]]; then
        log_info "Motor durduruldu" audit
        [[ "$quiet" != "quiet" ]] && echo "$(msg service_stopped)"
    fi
}

engine_cleanup() {
    if [[ -x "$ENGINE_BIN" ]]; then
        "$ENGINE_BIN" cleanup 2>/dev/null || true
        log_info "engine cleanup calistirildi"
    fi
}

install_launchd() {
    require_root
    ensure_dirs
    sync_to_install
    cat > "$LAUNCHD_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCHD_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${LIB_DIR}/autostart.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/launchd.err.log</string>
</dict>
</plist>
EOF
    chmod 644 "$LAUNCHD_PLIST"
    launchctl bootout system/"${LAUNCHD_LABEL}" 2>/dev/null || true
    launchctl bootstrap system "$LAUNCHD_PLIST"
    launchctl enable system/"${LAUNCHD_LABEL}"
    log_info "launchd daemon kuruldu (root)" audit
}

uninstall_launchd() {
    require_root
    launchctl bootout system/"${LAUNCHD_LABEL}" 2>/dev/null || true
    rm -f "$LAUNCHD_PLIST"
}

MENUBAR_APP="/Applications/Amfetamin.app"
MENUBAR_BIN="$MENUBAR_APP/Contents/MacOS/amfetamin"
MENUBAR_LEGACY_APP="/Applications/Amfetamin MenuBar.app"
MENUBAR_AGENT_LABEL="com.furkandvrc.amfetamin"
MENUBAR_PLIST="$USER_HOME/Library/LaunchAgents/${MENUBAR_AGENT_LABEL}.plist"

install_control_cli() {
    cp "$MACOS_DIR/amfetamin" "$BIN_DIR/amfetamin-ctl"
    chmod +x "$BIN_DIR/amfetamin-ctl"
    log_info "amfetamin-ctl kuruldu" audit
}

install_menubar_app() {
    local app_src="$MACOS_DIR/Amfetamin.app"
    if [[ ! -d "$app_src" ]]; then
        return 1
    fi
    rm -rf "$MENUBAR_APP" "$MENUBAR_LEGACY_APP"
    pkill -f "amfetamin-menubar" 2>/dev/null || true
    cp -R "$app_src" "$MENUBAR_APP"
    chown -R "$(real_user):staff" "$MENUBAR_APP"
    log_info "Amfetamin.app /Applications'a kuruldu" audit
    install_menubar_agent
    sudo -u "$(real_user)" open -a "$MENUBAR_APP" 2>/dev/null || true
    return 0
}

build_menubar_as_user() {
    local u
    u="$(real_user)"
    if [[ ! -x "$MACOS_DIR/build-menubar.sh" ]]; then
        echo "$(msg build_script_missing)" >&2
        return 1
    fi
    if ! command -v swift >/dev/null 2>&1; then
        echo "$(msg swift_missing)" >&2
        return 1
    fi
    echo "$(msg menubar_building)"
    sudo -u "$u" bash "$MACOS_DIR/build-menubar.sh"
}

ensure_menubar_app() {
    if [[ -d "$MACOS_DIR/Amfetamin.app" ]]; then
        return 0
    fi
    build_menubar_as_user
}

install_menubar() {
    require_root
    ensure_menubar_app || return 1
    install_menubar_app || return 1
    echo "$(msg menubar_installed)"
}

menubar_installed() {
    [[ -x "$MENUBAR_BIN" ]]
}

install_menubar_agent() {
    local uid u
    [[ -x "$MENUBAR_BIN" ]] || return 0
    u="$(real_user)"
    uid="$(id -u "$u")"
    mkdir -p "$USER_HOME/Library/LaunchAgents"
    cat > "$MENUBAR_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${MENUBAR_AGENT_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${MENUBAR_BIN}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
    chown "$u:staff" "$MENUBAR_PLIST"
    launchctl bootout "gui/$uid/com.furkandvrc.amfetamin.menubar" 2>/dev/null || true
    rm -f "$USER_HOME/Library/LaunchAgents/com.furkandvrc.amfetamin.menubar.plist"
    launchctl bootout "gui/$uid/${MENUBAR_AGENT_LABEL}" 2>/dev/null || true
    sudo -u "$u" launchctl bootstrap "gui/$uid" "$MENUBAR_PLIST" 2>/dev/null || true
    sudo -u "$u" launchctl enable "gui/$uid/${MENUBAR_AGENT_LABEL}" 2>/dev/null || true
    sudo -u "$u" launchctl kickstart -k "gui/$uid/${MENUBAR_AGENT_LABEL}" 2>/dev/null || true
    log_info "MenuBar otomatik baslatma kuruldu" audit
}

uninstall_menubar_agent() {
    local uid u
    u="$(real_user)"
    uid="$(id -u "$u")"
    launchctl bootout "gui/$uid/${MENUBAR_AGENT_LABEL}" 2>/dev/null || true
    launchctl bootout "gui/$uid/com.furkandvrc.amfetamin.menubar" 2>/dev/null || true
    rm -f "$MENUBAR_PLIST" "$USER_HOME/Library/LaunchAgents/com.furkandvrc.amfetamin.menubar.plist"
    log_info "Menu otomatik baslatma kaldirildi" audit
}

install_to_device() {
    require_root
    log_info "Cihaza kurulum basladi" audit
    sync_to_install
    ensure_engine_binary
    install_control_cli
    cp "$MACOS_DIR/lib/autostart.sh" "$LIB_DIR/autostart.sh"
    chmod +x "$LIB_DIR/autostart.sh"
    mkdir -p "/Library/Application Support/Amfetamin"
    echo "$INSTALL_ROOT" > "/Library/Application Support/Amfetamin/install-root.conf"
    install_launchd

    echo ""
    if install_menubar; then
        MENUBAR_NOTE="$(msg menubar_note_ok)"
    else
        MENUBAR_NOTE="$(msg menubar_note_fail)"
    fi
    echo ""

    if should_auto_tune; then
        echo "$(msg ttl_auto_tuning)"
        auto_tune_ttl
    else
        start_engine_hidden 0 || true
    fi

    if ! is_engine_running; then
        echo "$(msg install_engine_failed)" >&2
        exit 1
    fi

    cat <<MSG
$(msg install_complete)

  $(msg label_location) $INSTALL_ROOT
  $(msg label_ttl)            $(cfg_get fakeTtl)
  $(msg label_autostart) $(msg autostart_on)
  ${MENUBAR_NOTE:-Menu bar: Unknown}

$(msg install_troubleshoot)
MSG
}

full_cleanup() {
    require_root
    log_info "Kaldirma basladi" audit

    stop_engine quiet || true
    engine_cleanup
    uninstall_launchd || true
    uninstall_menubar_agent || true
    rm -rf "$MENUBAR_APP" "$MENUBAR_LEGACY_APP" 2>/dev/null || true

    cfg_set autoTuneDone false 2>/dev/null || true
    log_info "Kaldirma tamamlandi" audit

    cat <<MSG
$(msg cleanup_complete)

  $(msg cleanup_motor_stopped)
  $(msg cleanup_network)
  $(msg cleanup_autostart)
  $(msg cleanup_ttl)
MSG
}

show_status() {
    echo "=== amfetamin macOS ==="
    echo "Version:   $(cfg_get version)"
    echo "Engine:    $([[ -x "$ENGINE_BIN" ]] && echo installed || echo missing)"
    echo "Running:   $(is_engine_running && echo yes || echo no)"
    echo "launchd:   $([[ -f "$LAUNCHD_PLIST" ]] && echo installed || echo missing)"
    echo "App:       $(menubar_installed && echo installed || echo missing)"
    echo "fakeTtl:   $(cfg_get fakeTtl)"
    echo "splitTunnel: $(cfg_get splitTunnel)"
    echo "Location:  $INSTALL_ROOT"
}
