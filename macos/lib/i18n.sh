#!/bin/bash
# amfetamin macOS — i18n (device language: tr* → Turkish, else English)

amfetamin_apple_primary_lang() {
    defaults read -g AppleLanguages 2>/dev/null | awk -F'"' '/"/ { if ($2 != "" && $2 !~ /^\(|\)$/) { print $2; exit } }'
}

amfetamin_detect_lang() {
    if [[ -n "${AMFETAMIN_LANG:-}" ]]; then
        case "$(printf '%s' "$AMFETAMIN_LANG" | tr '[:upper:]' '[:lower:]')" in
            tr|tr_*) echo tr; return ;;
            en|en_*) echo en; return ;;
        esac
    fi
    local primary
    primary="$(amfetamin_apple_primary_lang)"
    if [[ -n "$primary" ]]; then
        primary="$(printf '%s' "$primary" | tr '[:upper:]' '[:lower:]')"
        if [[ "$primary" == tr* ]]; then
            echo tr
        else
            echo en
        fi
        return
    fi
    local locale="${LANG:-${LC_ALL:-en_US.UTF-8}}"
    if [[ "$locale" == tr* ]]; then
        echo tr
    else
        echo en
    fi
}

AMFETAMIN_LANG="$(amfetamin_detect_lang)"

msg() {
    local key="$1"
    case "${AMFETAMIN_LANG}:${key}" in
        en:admin_required) echo "Administrator required. Run: sudo bash amfetamin $2" ;;
        tr:admin_required) echo "Yonetici gerekli. Calistirin: sudo bash amfetamin $2" ;;

        en:unsupported_arch) echo "Unsupported architecture: $2" ;;
        tr:unsupported_arch) echo "Desteklenmeyen mimari: $2" ;;

        en:service_already_running) echo "Service is already running" ;;
        tr:service_already_running) echo "Hizmet zaten calisiyor" ;;

        en:service_started) echo "Service started" ;;
        tr:service_started) echo "Hizmet baslatildi" ;;

        en:service_stopped) echo "Service stopped" ;;
        tr:service_stopped) echo "Hizmet durduruldu" ;;

        en:engine_start_failed) echo "Engine failed to start" ;;
        tr:engine_start_failed) echo "Motor baslatilamadi" ;;

        en:ttl_set) echo "TTL set to: $2" ;;
        tr:ttl_set) echo "TTL ayarlandi: $2" ;;

        en:build_script_missing) echo "build-menubar.sh not found" ;;
        tr:build_script_missing) echo "build-menubar.sh bulunamadi" ;;

        en:swift_missing) echo "Swift not found. Install: xcode-select --install" ;;
        tr:swift_missing) echo "Swift bulunamadi. Kurun: xcode-select --install" ;;

        en:menubar_building) echo "Building menu bar app..." ;;
        tr:menubar_building) echo "Menu cubugu uygulamasi derleniyor..." ;;

        en:menubar_installed) echo "Menu bar app installed. Look for the shield icon in the menu bar." ;;
        tr:menubar_installed) echo "Menu cubugu kuruldu. Ust cubukta kalkan ikonu gorunmeli." ;;

        en:menubar_note_ok) echo "Menu bar: Installed" ;;
        tr:menubar_note_ok) echo "Menu cubugu: Kurulu" ;;

        en:menubar_note_fail) echo "Menu bar: Failed (xcode-select --install, then: sudo bash amfetamin menubar)" ;;
        tr:menubar_note_fail) echo "Menu cubugu: Kurulamadi (xcode-select --install, sonra: sudo bash amfetamin menubar)" ;;

        en:ttl_auto_tuning) echo "Auto-tuning TTL (Discord test)..." ;;
        tr:ttl_auto_tuning) echo "TTL otomatik ayarlaniyor (Discord test)..." ;;

        en:install_engine_failed) echo "Install saved but engine did not start." ;;
        tr:install_engine_failed) echo "Kurulum kaydedildi ama motor baslamadi." ;;

        en:install_complete) echo "Installation complete." ;;
        tr:install_complete) echo "Kurulum tamamlandi." ;;

        en:cleanup_complete) echo "Removal complete." ;;
        tr:cleanup_complete) echo "Kaldirma tamamlandi." ;;

        en:label_location) echo "Location:" ;;
        tr:label_location) echo "Konum:" ;;

        en:label_ttl) echo "TTL:" ;;
        tr:label_ttl) echo "TTL:" ;;

        en:label_autostart) echo "Auto-start:" ;;
        tr:label_autostart) echo "Otomatik baslat:" ;;

        en:autostart_on) echo "Enabled" ;;
        tr:autostart_on) echo "Acik" ;;

        en:install_troubleshoot) echo "If you have issues: bash amfetamin diagnose" ;;
        tr:install_troubleshoot) echo "Sorun yasarsaniz: bash amfetamin diagnose" ;;

        en:cleanup_motor_stopped) echo "Engine stopped" ;;
        tr:cleanup_motor_stopped) echo "Motor durduruldu" ;;

        en:cleanup_network) echo "Network settings restored" ;;
        tr:cleanup_network) echo "Ag ayarlari geri alindi" ;;

        en:cleanup_autostart) echo "Auto-start disabled" ;;
        tr:cleanup_autostart) echo "Otomatik baslat devre disi birakildi" ;;

        en:cleanup_ttl) echo "TTL setting reset" ;;
        tr:cleanup_ttl) echo "TTL ayari sifirlandi" ;;

        en:unknown_command) echo "Unknown command: $2" ;;
        tr:unknown_command) echo "Bilinmeyen komut: $2" ;;

        en:usage_title) echo "Usage:" ;;
        tr:usage_title) echo "Kullanim:" ;;

        en:usage_install) echo "  ./amfetamin install      Install to device (sudo)" ;;
        tr:usage_install) echo "  ./amfetamin install      Cihaza kur (sudo)" ;;

        en:usage_start) echo "  ./amfetamin start        Start (sudo)" ;;
        tr:usage_start) echo "  ./amfetamin start        Baslat (sudo)" ;;

        en:usage_stop) echo "  ./amfetamin stop         Stop (sudo)" ;;
        tr:usage_stop) echo "  ./amfetamin stop         Durdur (sudo)" ;;

        en:usage_cleanup) echo "  ./amfetamin cleanup      Uninstall and reset (sudo)" ;;
        tr:usage_cleanup) echo "  ./amfetamin cleanup      Kaldir ve sifirla (sudo)" ;;

        en:usage_status) echo "  ./amfetamin status       Status" ;;
        tr:usage_status) echo "  ./amfetamin status       Durum" ;;

        en:usage_tune) echo "  ./amfetamin tune         Re-tune TTL (sudo)" ;;
        tr:usage_tune) echo "  ./amfetamin tune         TTL yeniden ayarla (sudo)" ;;

        en:usage_test) echo "  ./amfetamin test         Connection test" ;;
        tr:usage_test) echo "  ./amfetamin test         Baglanti testi" ;;

        en:usage_logs) echo "  ./amfetamin logs         Recent logs" ;;
        tr:usage_logs) echo "  ./amfetamin logs         Son loglar" ;;

        en:usage_open_logs) echo "  ./amfetamin open-logs    Open log folder in Finder" ;;
        tr:usage_open_logs) echo "  ./amfetamin open-logs    Log klasorunu Finder'da ac" ;;

        en:usage_diagnose) echo "  bash amfetamin diagnose  Diagnostic report" ;;
        tr:usage_diagnose) echo "  bash amfetamin diagnose  Teshis raporu" ;;

        en:usage_menubar) echo "  sudo bash amfetamin menubar  Install menu bar app" ;;
        tr:usage_menubar) echo "  sudo bash amfetamin menubar  Menu cubugunu kur/derle" ;;

        en:usage_example) echo "Example: sudo bash amfetamin install" ;;
        tr:usage_example) echo "Ornek: sudo bash amfetamin install" ;;

        en:diag_title) echo "=== AMFETAMIN macOS DIAGNOSTICS ===" ;;
        tr:diag_title) echo "=== AMFETAMIN macOS TESHIS ===" ;;

        en:diag_date) echo "Date:" ;;
        tr:diag_date) echo "Tarih:" ;;

        en:diag_root_yes) echo "yes" ;;
        tr:diag_root_yes) echo "evet" ;;

        en:diag_root_no) echo "no" ;;
        tr:diag_root_no) echo "hayir" ;;

        en:diag_report) echo "Report:" ;;
        tr:diag_report) echo "Rapor:" ;;

        en:diag_done) echo "=== DONE ===" ;;
        tr:diag_done) echo "=== BITTI ===" ;;

        en:log_app) echo "=== app.log (last $2 lines) ===" ;;
        tr:log_app) echo "=== app.log (son $2 satir) ===" ;;

        en:log_audit) echo "=== audit.log (last 10) ===" ;;
        tr:log_audit) echo "=== audit.log (son 10) ===" ;;

        en:log_engine) echo "=== engine.log (last 15) ===" ;;
        tr:log_engine) echo "=== engine.log (son 15) ===" ;;

        en:build_running) echo "Building..." ;;
        tr:build_running) echo "Derleniyor..." ;;

        en:build_ready) echo "Ready:" ;;
        tr:build_ready) echo "Hazir:" ;;

        en:build_binary_missing) echo "Binary not found. Are Xcode CLI tools installed?" ;;
        tr:build_binary_missing) echo "Binary bulunamadi. Xcode CLI tools kurulu mu?" ;;

        en:build_install_hint) echo "Install: sudo bash amfetamin menubar" ;;
        tr:build_install_hint) echo "Install: sudo bash amfetamin menubar" ;;

        *) echo "$key" ;;
    esac
}
