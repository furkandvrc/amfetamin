import Foundation
import AppKit

@MainActor
final class AmfetaminController: ObservableObject {
    @Published var version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "?"
    @Published var isRunning = false
    @Published var isBusy = false
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
        let ctl = ctlPath
        guard FileManager.default.fileExists(atPath: ctl) else {
            statusLine = L10n.installNotFound
            isRunning = false
            launchdInstalled = false
            return
        }
        // Shell work never runs on the main thread: the menu must stay responsive.
        Task {
            let out = await Task.detached { Self.shell("\(Self.shellQuote(ctl)) status", sudo: false) }.value
            if out.contains("Unknown") || out.contains("No such file") || out.isEmpty {
                statusLine = L10n.statusUnreadable
                isRunning = false
                return
            }
            parseStatus(out)
            if !isBusy { statusLine = isRunning ? L10n.active : L10n.inactive }
        }
    }

    func run(_ cmd: String) { execute(cmd, sudo: false) }

    func runSudo(_ cmd: String) { execute(cmd, sudo: true) }

    private func execute(_ cmd: String, sudo: Bool, completion: ((String) -> Void)? = nil) {
        guard !isBusy else { return }
        isBusy = true
        statusLine = L10n.working
        let command = "\(Self.shellQuote(ctlPath)) \(cmd)"
        Task {
            let out = await Task.detached { Self.shell(command, sudo: sudo) }.value
            lastMessage = out
            isBusy = false
            completion?(out)
            refresh()
        }
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
        execute("cleanup", sudo: true) { out in
            guard out.localizedCaseInsensitiveContains("complete") || out.localizedCaseInsensitiveContains("tamamlandi") else { return }
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

    nonisolated private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated private static func shell(_ command: String, sudo: Bool) -> String {
        let task = Process()
        let pipe = Pipe()
        if sudo {
            // NSAppleScript is main-thread only; osascript runs the same
            // privileged prompt in a separate process.
            let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        } else {
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-c", command]
        }
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            let out = String(data: data, encoding: .utf8) ?? ""
            if sudo && task.terminationStatus != 0 { return "\(L10n.errorPrefix) \(out)" }
            return out
        } catch {
            return "\(L10n.errorPrefix) \(error.localizedDescription)"
        }
    }
}
