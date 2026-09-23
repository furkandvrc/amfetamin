#!/bin/bash
# amfetamin macOS — core
#
# Must stay compatible with /bin/bash 3.2 (the bash macOS ships): no namerefs,
# associative arrays, mapfile or ${var,,}.

set -euo pipefail

MACOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=i18n.sh
source "$MACOS_DIR/lib/i18n.sh"
# shellcheck source=logger.sh
source "$MACOS_DIR/lib/logger.sh"

REPO="furkandvrc/amfetamin"

real_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        echo "$SUDO_USER"
    elif [[ "$(id -u)" -eq 0 ]]; then
        # launchd / osascript "with administrator privileges": use the console user.
        local console
        console="$(stat -f %Su /dev/console 2>/dev/null || true)"
        if [[ -n "$console" && "$console" != "root" ]]; then echo "$console"; else id -un; fi
    else
        id -un
    fi
}

real_home() {
    local u
    u="$(real_user)"
    dscl . -read "/Users/$u" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || eval echo "~$u"
}

INSTALL_ROOT_CONF="/Library/Application Support/Amfetamin/install-root.conf"
INSTALL_ROOT="${AMFETAMIN_INSTALL_ROOT:-}"
if [[ -z "$INSTALL_ROOT" && -f "$INSTALL_ROOT_CONF" ]]; then
    INSTALL_ROOT="$(cat "$INSTALL_ROOT_CONF")"
fi
if [[ -z "$INSTALL_ROOT" ]]; then
    INSTALL_ROOT="$(real_home)/Library/Application Support/Amfetamin"
fi
BIN_DIR="$INSTALL_ROOT/bin"
LOG_DIR="$INSTALL_ROOT/logs"
LIB_DIR="$INSTALL_ROOT/lib"
CONFIG_PATH="$INSTALL_ROOT/config.json"
ENGINE_BIN="$BIN_DIR/amfetamin-engine"
ENGINE_TAG_FILE="$BIN_DIR/engine-tag.txt"
ENGINE_LOG="$LOG_DIR/engine.log"
LAUNCHD_LABEL="com.furkandvrc.amfetamin"
LAUNCHD_PLIST="/Library/LaunchDaemons/${LAUNCHD_LABEL}.plist"
PID_FILE="$INSTALL_ROOT/amfetamin.pid"

export AMFETAMIN_LOG_DIR="$LOG_DIR"
mkdir -p "$AMFETAMIN_LOG_DIR" 2>/dev/null || true

app_version() {
    local f
    for f in "$MACOS_DIR/VERSION" "$MACOS_DIR/../VERSION" "$INSTALL_ROOT/VERSION"; do
        if [[ -f "$f" ]]; then
            tr -d '[:space:]' < "$f"
            return
        fi
    done
    echo "dev"
}

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

# ------------------------------------------------------------------ config
# JSON is handled with JavaScript for Automation (always present), not
# python3 — on a Mac without the Xcode tools python3 pops an install dialog.

cfg_js() {
    local file="$CONFIG_PATH"
    [[ -f "$file" ]] || file="$(project_root)/config.json"
    /usr/bin/osascript -l JavaScript - "$file" "$@" <<'JS'
ObjC.import('Foundation');

var DEFAULTS = {
  dohUpstream: 'cloudflare,google',
  fakeTtl: 8,
  autoTuneTtl: true,
  autoTuneDone: false,
  autoTuneUrl: 'https://discord.com',
  fakeTtlCandidates: [6, 8, 10, 12, 14, 5, 7, 9, 11],
  bypassPresets: ['warframe'],
  bypassPortsCustom: [],
  splitTunnel: false,
  filterAaaa: true,
  engineVerbose: false
};

// Keep in sync with windows/src/AppConfig.cs (GamePreset.All).
var PRESETS = {
  auto: ['udp:auto'],
  warframe: ['udp:4950-4955', 'tcp:4950-4955', 'tcp:6695-6709'],
  lol: ['udp:5000-5500', 'udp:7000-8000', 'udp:8393'],
  rust: ['udp:28015-28050'],
  steam: ['udp:27000-27100', 'tcp:27015', 'tcp:27036', 'udp:27031-27036'],
  fortnite: ['udp:9000-9100'],
  apex: ['udp:37000-40000'],
  gta: ['udp:6672', 'udp:61455-61458']
};

function readConfig(path) {
  var s = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  if (s.isNil()) return {};
  try { return JSON.parse(ObjC.unwrap(s).replace(/^﻿/, '')); } catch (e) { return {}; }
}

function value(cfg, key) {
  var v = cfg[key];
  if (v === undefined || v === null || v === '') v = DEFAULTS[key];
  return v;
}

function asList(v) {
  if (v === undefined || v === null) return [];
  if (typeof v === 'string') return v.trim() ? [v.trim()] : [];
  return v;
}

function run(argv) {
  var path = argv[0], action = argv[1], cfg = readConfig(path);
  if (action === 'get') {
    var v = value(cfg, argv[2]);
    if (v === undefined) return '';
    if (Array.isArray(v)) return v.join(',');
    return String(v);
  }
  if (action === 'rules') {
    var out = [], seen = {};
    asList(value(cfg, 'bypassPresets')).forEach(function (id) {
      (PRESETS[String(id).toLowerCase()] || []).forEach(function (r) { if (!seen[r]) { seen[r] = 1; out.push(r); } });
    });
    asList(cfg.bypassPortsCustom).forEach(function (r) {
      r = String(r).trim();
      if (r && !seen[r]) { seen[r] = 1; out.push(r); }
    });
    return out.join('\n');
  }
  if (action === 'set') {
    var key = argv[2], raw = argv[3], val = raw;
    if (raw === 'true' || raw === 'false') val = raw === 'true';
    else if (/^-?\d+$/.test(raw)) val = parseInt(raw, 10);
    cfg[key] = val;
    var text = JSON.stringify(cfg, null, 2) + '\n';
    $(text).writeToFileAtomicallyEncodingError(argv[4] || path, true, $.NSUTF8StringEncoding, null);
    return '';
  }
  return '';
}
JS
}

cfg_get() { cfg_js get "$1"; }

cfg_set() {
    ensure_dirs
    [[ -f "$CONFIG_PATH" ]] || cp "$(project_root)/config.json" "$CONFIG_PATH" 2>/dev/null || echo '{}' > "$CONFIG_PATH"
    CONFIG_PATH="$CONFIG_PATH" cfg_js set "$1" "$2" "$CONFIG_PATH" >/dev/null
    chown "$(real_user)" "$CONFIG_PATH" 2>/dev/null || true
}

cfg_rules() { cfg_js rules; }

is_root() { [[ "$(id -u)" -eq 0 ]]; }

require_root() {
    if ! is_root; then
        echo "$(msg admin_required "$*")" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------ engine

engine_asset() {
    case "$(uname -m)" in
        arm64)  echo "amfetamin-engine-darwin-arm64" ;;
        x86_64) echo "amfetamin-engine-darwin-amd64" ;;
        *) echo "$(msg unsupported_arch "$(uname -m)")" >&2; return 1 ;;
    esac
}

engine_needs_install() {
    [[ -x "$ENGINE_BIN" ]] || return 0
    [[ -f "$ENGINE_TAG_FILE" ]] || return 0
    [[ "$(tr -d '[:space:]' < "$ENGINE_TAG_FILE")" != "v$(app_version)" ]]
}

install_engine_binary() {
    ensure_dirs
    local asset tag tmp bundled
    asset="$(engine_asset)"
    tag="v$(app_version)"
    tmp="$BIN_DIR/.engine.download"
    bundled="$MACOS_DIR/engine/$asset"

    if [[ -f "$bundled" ]]; then
        cp "$bundled" "$tmp"
        log_info "Motor paketten kuruldu: $bundled"
    else
        local base="https://github.com/$REPO/releases/download/$tag"
        log_info "Indiriliyor: $base/$asset"
        curl -fsSL --retry 3 "$base/checksums.txt" -o "$BIN_DIR/checksums.txt"
        curl -fsSL --retry 3 "$base/$asset" -o "$tmp"
        local expected actual
        expected="$(awk -v a="$asset" '$NF ~ a"$" {print $1; exit}' "$BIN_DIR/checksums.txt")"
        actual="$(shasum -a 256 "$tmp" | awk '{print $1}')"
        if [[ -z "$expected" || "$expected" != "$actual" ]]; then
            rm -f "$tmp"
            log_error "SHA256 uyusmadi ($asset)"
            echo "SHA256 mismatch for $asset" >&2
            return 1
        fi
    fi

    chmod 755 "$tmp"
    xattr -d com.apple.quarantine "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$ENGINE_BIN"
    printf '%s\n' "$tag" > "$ENGINE_TAG_FILE"
    log_info "Motor kuruldu: $ENGINE_BIN ($tag)" audit
}

ensure_engine_binary() {
    engine_needs_install || return 0
    stop_engine quiet || true
    install_engine_binary
}

sync_to_install() {
    ensure_dirs
    local proot
    proot="$(project_root)"
    if [[ ! -f "$CONFIG_PATH" && -f "$proot/config.json" ]]; then
        cp "$proot/config.json" "$CONFIG_PATH"
    fi
    cp -R "$proot/lib/"* "$LIB_DIR/" 2>/dev/null || true
    [[ -f "$proot/VERSION" ]] && cp "$proot/VERSION" "$INSTALL_ROOT/VERSION"
    [[ -f "$proot/../VERSION" ]] && cp "$proot/../VERSION" "$INSTALL_ROOT/VERSION"
    chown -R "$(real_user)" "$INSTALL_ROOT" 2>/dev/null || true
    log_info "Dosyalar senkronize edildi"
}

is_engine_running() {
    pgrep -x amfetamin-engine >/dev/null 2>&1
}

engine_pid() {
    pgrep -x amfetamin-engine 2>/dev/null | head -1
}

# Fills the global ENGINE_ARGS array (bash 3.2 has no namerefs).
build_engine_args() {
    local ttl="${1:-0}" rule
    [[ "$ttl" -gt 0 ]] || ttl="$(cfg_get fakeTtl)"
    [[ -n "$ttl" && "$ttl" -gt 0 ]] || ttl=8
    ENGINE_ARGS=( run --log-file "$ENGINE_LOG" --doh-upstream "$(cfg_get dohUpstream)" --fake-ttl "$ttl" )
    [[ "$(cfg_get splitTunnel)" == "true" ]] && ENGINE_ARGS+=( --split-tunnel )
    [[ "$(cfg_get filterAaaa)" == "false" ]] && ENGINE_ARGS+=( --filter-aaaa=false )
    while IFS= read -r rule; do
        [[ -n "$rule" ]] && ENGINE_ARGS+=( --bypass-rule "$rule" )
    done < <(cfg_rules)
    [[ "$(cfg_get engineVerbose)" == "true" ]] && ENGINE_ARGS+=( -v )
    return 0
}

log_size() {
    if [[ -f "$ENGINE_LOG" ]]; then stat -f %z "$ENGINE_LOG"; else echo 0; fi
}

# Waits until the engine logs readiness after byte offset $1.
wait_engine_ready() {
    local offset="$1" i chunk
    for i in $(seq 1 80); do
        sleep 0.25
        chunk="$(tail -c +"$((offset + 1))" "$ENGINE_LOG" 2>/dev/null || true)"
        if [[ "$chunk" == *"engine running"* ]]; then
            return 0
        fi
        if [[ "$chunk" == *"engine exited with error"* ]]; then
            printf '%s\n' "$chunk" | grep -E 'level=(error|fatal)' | tail -3 >&2 || true
            return 1
        fi
    done
    is_engine_running
}

daemon_installed() { [[ -f "$LAUNCHD_PLIST" ]]; }

daemon_loaded() { launchctl print "system/$LAUNCHD_LABEL" >/dev/null 2>&1; }

# Starts the engine. With a TTL override (auto-tune) it runs a one-off
# process; otherwise launchd supervises it when the daemon is installed.
start_engine() {
    local ttl_override="${1:-0}" quiet="${2:-}"
    require_root
    ensure_engine_binary

    if is_engine_running; then
        if [[ "$ttl_override" -eq 0 ]]; then
            [[ "$quiet" == "quiet" ]] || echo "$(msg service_already_running)"
            return 0
        fi
        stop_engine quiet
    fi

    local offset
    offset="$(log_size)"
    if [[ "$ttl_override" -eq 0 ]] && daemon_installed; then
        daemon_loaded || launchctl bootstrap system "$LAUNCHD_PLIST" 2>/dev/null || true
        launchctl kickstart -k "system/$LAUNCHD_LABEL"
    else
        build_engine_args "$ttl_override"
        nohup "$ENGINE_BIN" "${ENGINE_ARGS[@]}" >/dev/null 2>>"$LOG_DIR/engine.err.log" &
        echo $! > "$PID_FILE"
    fi

    if wait_engine_ready "$offset"; then
        log_info "Motor baslatildi PID=$(engine_pid)" audit
        [[ "$quiet" == "quiet" ]] || echo "$(msg service_started)"
        return 0
    fi
    log_error "$(msg engine_start_failed)"
    [[ "$quiet" == "quiet" ]] || echo "$(msg engine_start_failed) — $ENGINE_LOG" >&2
    return 1
}

# Asks the engine to exit (SIGTERM restores DNS), escalating only if needed.
# launchd does not restart it: KeepAlive only covers unsuccessful exits.
stop_engine() {
    local quiet="${1:-}" i
    if ! is_engine_running; then
        rm -f "$PID_FILE"
        return 0
    fi
    pkill -TERM -x amfetamin-engine 2>/dev/null || true
    for i in $(seq 1 40); do
        is_engine_running || break
        sleep 0.25
    done
    if is_engine_running; then
        pkill -KILL -x amfetamin-engine 2>/dev/null || true
        sleep 0.5
        engine_cleanup
    fi
    rm -f "$PID_FILE"
    log_info "Motor durduruldu" audit
    [[ "$quiet" == "quiet" ]] || echo "$(msg service_stopped)"
}

engine_cleanup() {
    if [[ -x "$ENGINE_BIN" ]]; then
        "$ENGINE_BIN" cleanup >/dev/null 2>&1 || true
        log_info "engine cleanup calistirildi"
    fi
}

probe_url() {
    local url="${1:-https://discord.com}" timeout="${2:-8}" code
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null || true)"
    [[ -n "$code" && "$code" != "000" ]]
}

test_bypass_reachable() { probe_url "$@"; }

# Tries TTL candidates until the test site loads through the engine: too low
# never reaches the DPI box, too high reaches the server and breaks TLS.
auto_tune_ttl() {
    require_root
    local test_url candidates ttl best="" total i=0
    test_url="$(cfg_get autoTuneUrl)"
    candidates="$(cfg_get fakeTtlCandidates)"
    total="$(printf '%s' "$candidates" | tr ',' '\n' | grep -c . || true)"

    log_info "TTL otomatik ayar basladi ($test_url)" audit
    for ttl in $(printf '%s' "$candidates" | tr ',' ' '); do
        i=$((i + 1))
        echo "  TTL $ttl ($i/$total)..."
        stop_engine quiet
        if ! start_engine "$ttl" quiet; then
            continue
        fi
        sleep 1.5
        if probe_url "$test_url" 8; then
            best="$ttl"
            log_info "TTL $ttl calisti"
            break
        fi
    done
    stop_engine quiet

    if [[ -z "$best" ]]; then
        best="$(cfg_get fakeTtl)"
        [[ -n "$best" ]] || best=8
        log_warn "Uygun TTL bulunamadi, $best kullaniliyor"
    fi
    cfg_set fakeTtl "$best"
    cfg_set autoTuneDone true
    start_engine 0 quiet || true
    echo "$(msg ttl_set "$best")"
}

should_auto_tune() {
    [[ "$(cfg_get autoTuneTtl)" == "true" ]] || return 1
    [[ "$(cfg_get autoTuneDone)" != "true" ]]
}

# ------------------------------------------------------------------ launchd

install_launchd() {
    require_root
    ensure_dirs
    sync_to_install
    cp "$MACOS_DIR/lib/autostart.sh" "$LIB_DIR/autostart.sh"
    chmod 755 "$LIB_DIR/autostart.sh"
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
    <!-- Restart after crashes (and while the network comes up at boot),
         but not after a clean stop. -->
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>15</integer>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/launchd.err.log</string>
</dict>
</plist>
EOF
    chmod 644 "$LAUNCHD_PLIST"
    chown root:wheel "$LAUNCHD_PLIST"
    launchctl bootout "system/${LAUNCHD_LABEL}" 2>/dev/null || true
    launchctl bootstrap system "$LAUNCHD_PLIST"
    launchctl enable "system/${LAUNCHD_LABEL}"
    log_info "launchd daemon kuruldu (root)" audit
}

uninstall_launchd() {
    require_root
    launchctl bootout "system/${LAUNCHD_LABEL}" 2>/dev/null || true
    rm -f "$LAUNCHD_PLIST"
}

# ------------------------------------------------------------------ menu bar

MENUBAR_APP="/Applications/Amfetamin.app"
MENUBAR_BIN="$MENUBAR_APP/Contents/MacOS/amfetamin"
MENUBAR_LEGACY_APP="/Applications/Amfetamin MenuBar.app"
MENUBAR_AGENT_LABEL="com.furkandvrc.amfetamin.menu"
MENUBAR_PLIST="$(real_home)/Library/LaunchAgents/${MENUBAR_AGENT_LABEL}.plist"
LEGACY_AGENT_LABELS="com.furkandvrc.amfetamin com.furkandvrc.amfetamin.menubar"

install_control_cli() {
    cp "$MACOS_DIR/amfetamin" "$BIN_DIR/amfetamin-ctl"
    chmod 755 "$BIN_DIR/amfetamin-ctl"
    log_info "amfetamin-ctl kuruldu" audit
}

install_menubar_app() {
    local app_src="$MACOS_DIR/Amfetamin.app"
    [[ -d "$app_src" ]] || return 1
    rm -rf "$MENUBAR_APP" "$MENUBAR_LEGACY_APP"
    pkill -x amfetamin 2>/dev/null || true
    cp -R "$app_src" "$MENUBAR_APP"
    xattr -dr com.apple.quarantine "$MENUBAR_APP" 2>/dev/null || true
    chown -R "$(real_user):staff" "$MENUBAR_APP"
    log_info "Amfetamin.app /Applications'a kuruldu" audit
    install_menubar_agent
    return 0
}

build_menubar_as_user() {
    [[ -f "$MACOS_DIR/build-menubar.sh" ]] || { echo "$(msg build_script_missing)" >&2; return 1; }
    command -v swift >/dev/null 2>&1 || { echo "$(msg swift_missing)" >&2; return 1; }
    echo "$(msg menubar_building)"
    sudo -u "$(real_user)" bash "$MACOS_DIR/build-menubar.sh"
}

ensure_menubar_app() {
    [[ -d "$MACOS_DIR/Amfetamin.app" ]] || build_menubar_as_user
}

install_menubar() {
    require_root
    ensure_menubar_app || return 1
    install_menubar_app || return 1
    echo "$(msg menubar_installed)"
}

menubar_installed() { [[ -x "$MENUBAR_BIN" ]]; }

install_menubar_agent() {
    local uid u label
    [[ -x "$MENUBAR_BIN" ]] || return 0
    u="$(real_user)"
    uid="$(id -u "$u")"
    mkdir -p "$(dirname "$MENUBAR_PLIST")"
    for label in $LEGACY_AGENT_LABELS; do
        launchctl bootout "gui/$uid/$label" 2>/dev/null || true
        rm -f "$(real_home)/Library/LaunchAgents/$label.plist"
    done
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
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF
    chown "$u:staff" "$MENUBAR_PLIST"
    launchctl bootout "gui/$uid/${MENUBAR_AGENT_LABEL}" 2>/dev/null || true
    launchctl bootstrap "gui/$uid" "$MENUBAR_PLIST" 2>/dev/null || true
    launchctl kickstart -k "gui/$uid/${MENUBAR_AGENT_LABEL}" 2>/dev/null || true
    log_info "MenuBar otomatik baslatma kuruldu" audit
}

uninstall_menubar_agent() {
    local uid label
    uid="$(id -u "$(real_user)")"
    for label in "$MENUBAR_AGENT_LABEL" $LEGACY_AGENT_LABELS; do
        launchctl bootout "gui/$uid/$label" 2>/dev/null || true
        rm -f "$(real_home)/Library/LaunchAgents/$label.plist"
    done
    pkill -x amfetamin 2>/dev/null || true
    log_info "Menu otomatik baslatma kaldirildi" audit
}

# ------------------------------------------------------------------ install

install_to_device() {
    require_root
    log_info "Cihaza kurulum basladi" audit
    sync_to_install
    ensure_engine_binary
    install_control_cli
    mkdir -p "$(dirname "$INSTALL_ROOT_CONF")"
    echo "$INSTALL_ROOT" > "$INSTALL_ROOT_CONF"
    install_launchd

    echo ""
    local menubar_note
    if install_menubar; then
        menubar_note="$(msg menubar_note_ok)"
    else
        menubar_note="$(msg menubar_note_fail)"
    fi
    echo ""

    if should_auto_tune; then
        echo "$(msg ttl_auto_tuning)"
        auto_tune_ttl
    else
        start_engine 0 quiet || true
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
  ${menubar_note}

$(msg install_troubleshoot)
MSG
}

full_cleanup() {
    require_root
    log_info "Kaldirma basladi" audit

    uninstall_launchd || true
    stop_engine quiet || true
    engine_cleanup
    uninstall_menubar_agent || true
    rm -rf "$MENUBAR_APP" "$MENUBAR_LEGACY_APP" 2>/dev/null || true
    rm -f "$INSTALL_ROOT_CONF"
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
    echo "Version:   $(app_version)"
    echo "Engine:    $([[ -x "$ENGINE_BIN" ]] && echo installed || echo missing)"
    echo "Running:   $(is_engine_running && echo yes || echo no)"
    echo "launchd:   $(daemon_installed && echo installed || echo missing)"
    echo "App:       $(menubar_installed && echo installed || echo missing)"
    echo "fakeTtl:   $(cfg_get fakeTtl)"
    echo "Rules:     $(cfg_rules | tr '\n' ' ')"
    echo "Location:  $INSTALL_ROOT"
}
