import Foundation

enum L10n {
    /// Primary macOS UI language from System Settings (AppleLanguages).
    private static var isTurkish: Bool {
        if let forced = ProcessInfo.processInfo.environment["AMFETAMIN_LANG"]?.lowercased() {
            if forced.hasPrefix("tr") { return true }
            if forced.hasPrefix("en") { return false }
        }

        if let primary = Locale.preferredLanguages.first?.lowercased() {
            return primary.hasPrefix("tr")
        }

        if let apple = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let first = apple.first?.lowercased() {
            return first.hasPrefix("tr")
        }

        return false
    }

    private static func pick(_ en: String, _ tr: String) -> String {
        isTurkish ? tr : en
    }

    static var loading: String { pick("Loading...", "Yukleniyor...") }
    static var installNotFound: String { pick("Installation not found", "Kurulum bulunamadi") }
    static var statusUnreadable: String { pick("Could not read status", "Durum okunamadi") }
    static var active: String { pick("Active", "Aktif") }
    static var inactive: String { pick("Inactive", "Kapali") }
    static var running: String { pick("Running", "Calisiyor") }
    static var stopped: String { pick("Stopped", "Durdu") }
    static var autostartOn: String { pick("Auto-start: On", "Otomatik acilis: Acik") }
    static var autostartOff: String { pick("Auto-start: Off", "Otomatik acilis: Kapali") }
    static var start: String { pick("Start", "Baslat") }
    static var stop: String { pick("Stop", "Durdur") }
    static var retuneTtl: String { pick("Re-tune TTL", "TTL Yeniden Ayarla") }
    static var openLogs: String { pick("Open Logs", "Loglari Ac") }
    static var connectionTest: String { pick("Connection Test", "Baglanti Testi") }
    static var uninstall: String { pick("Uninstall...", "Kaldir...") }
    static var refreshStatus: String { pick("Refresh Status", "Durumu Yenile") }
    static var quit: String { pick("Quit", "Cikis") }

    static var cleanupTitle: String { pick("Uninstall amfetamin?", "amfetamin kaldirilsin mi?") }
    static var cleanupBody: String {
        pick(
            "The engine will stop, network settings will be restored, and auto-start will be disabled.",
            "Motor durdurulur, ag ayarlari geri alinir ve otomatik baslat devre disi birakilir."
        )
    }
    static var cleanupConfirm: String { pick("Uninstall", "Kaldir") }
    static var cancel: String { pick("Cancel", "Iptal") }
    static var cleanupDoneTitle: String { pick("Removal complete", "Kaldirma tamamlandi") }
    static var cleanupDoneBody: String {
        pick(
            "Service stopped. Run install again to reinstall.",
            "Hizmet durduruldu. Yeniden kurmak icin install komutunu calistirin."
        )
    }
    static var errorPrefix: String { pick("Error:", "Hata:") }
    static var appleScriptFailed: String { pick("Could not run AppleScript", "AppleScript baslatilamadi") }
}
