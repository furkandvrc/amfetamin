import Foundation
import AppKit

@MainActor
final class AmfetaminController: ObservableObject {
    @Published var version = "3.1.2"
    @Published var isRunning = false
    @Published var launchdInstalled = false
    @Published var fakeTtl = "8"
    @Published var statusLine = L10n.loading
    @Published var lastMessage = ""

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        timer?.invalidate()
    }

    var installRoot: URL {
        let conf = URL(fileURLWithPath: "/Library/Application Support/Amfetamin/install-root.conf")
        if let text = try? String(contentsOf: conf, encoding: .utf8) {
            let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty { return URL(fileURLWithPath: path) }
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Amfetamin")
    }

    var ctlPath: String {
        installRoot.appendingPathComponent("bin/amfetamin-ctl").path
    }

    func refresh() {
        guard FileManager.default.fileExists(atPath: ctlPath) else {
            statusLine = L10n.installNotFound
            isRunning = false
            launchdInstalled = false
            return
        }
        let out = shell("\(shellQuote(ctlPath)) status", sudo: false)
        if out.contains("Unknown") || out.contains("No such file") || out.isEmpty {
            statusLine = L10n.statusUnreadable
            isRunning = false
            return
        }
        parseStatus(out)
        statusLine = isRunning ? L10n.active : L10n.inactive
    }

    func run(_ cmd: String) {
        lastMessage = shell("\(shellQuote(ctlPath)) \(cmd)", sudo: false)
        refresh()
    }

    func runSudo(_ cmd: String) {
        lastMessage = shell("\(shellQuote(ctlPath)) \(cmd)", sudo: true)
        refresh()
    }

    func openLogs() {
        NSWorkspace.shared.open(installRoot.appendingPathComponent("logs"))
    }

    func confirmCleanup() {
        let alert = NSAlert()
        alert.messageText = L10n.cleanupTitle
        alert.informativeText = L10n.cleanupBody
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.cleanupConfirm)
        alert.addButton(withTitle: L10n.cancel)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        runSudo("cleanup")
        if lastMessage.localizedCaseInsensitiveContains("complete") || lastMessage.localizedCaseInsensitiveContains("tamamlandi") {
            let ok = NSAlert()
            ok.messageText = L10n.cleanupDoneTitle
            ok.informativeText = L10n.cleanupDoneBody
            ok.runModal()
        }
    }

    private func parseStatus(_ text: String) {
        for line in text.split(separator: "\n") {
            let s = String(line).trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("Version:") {
                version = s.dropFirst("Version:".count).trimmingCharacters(in: .whitespaces)
            }
            if s.hasPrefix("Running:") {
                isRunning = s.contains("yes")
            }
            if s.hasPrefix("launchd:") {
                launchdInstalled = s.contains("installed")
            }
            if s.hasPrefix("fakeTtl:") {
                fakeTtl = s.dropFirst("fakeTtl:".count).trimmingCharacters(in: .whitespaces)
            }
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func shell(_ command: String, sudo: Bool) -> String {
        if sudo {
            let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let script = "do shell script \"\(escaped)\" with administrator privileges"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let output = appleScript.executeAndReturnError(&error)
                if let error { return "\(L10n.errorPrefix) \(error)" }
                return output.stringValue ?? ""
            }
            return L10n.appleScriptFailed
        }
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-lc", command]
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "\(L10n.errorPrefix) \(error.localizedDescription)"
        }
    }
}
