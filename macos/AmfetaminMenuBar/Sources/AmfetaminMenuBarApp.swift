import SwiftUI

@main
struct AmfetaminMenuBarApp: App {
    @StateObject private var controller = AmfetaminController()

    var body: some Scene {
        MenuBarExtra {
            AmfetaminMenuView(controller: controller)
        } label: {
            Image(systemName: controller.isRunning ? "shield.lefthalf.filled" : "shield.slash")
                .symbolRenderingMode(.palette)
                .foregroundStyle(controller.isRunning ? .green : .secondary)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct AmfetaminMenuView: View {
    @ObservedObject var controller: AmfetaminController

    var body: some View {
        Section {
            Text("amfetamin v\(controller.version)")
                .font(.headline)
            Text(controller.statusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section {
            Button(controller.isRunning ? L10n.running : L10n.stopped) {}
                .disabled(true)
            Button("TTL: \(controller.fakeTtl)") {}
                .disabled(true)
            Button(controller.launchdInstalled ? L10n.autostartOn : L10n.autostartOff) {}
                .disabled(true)
        }

        Divider()

        Button(L10n.start) { controller.runSudo("start") }
            .disabled(controller.isRunning)
        Button(L10n.stop) { controller.runSudo("stop") }
            .disabled(!controller.isRunning)
        Button(L10n.retuneTtl) { controller.runSudo("tune") }

        Divider()

        Button(L10n.openLogs) { controller.openLogs() }
        Button(L10n.connectionTest) { controller.run("test") }

        Divider()

        Button(L10n.uninstall) { controller.confirmCleanup() }
            .foregroundStyle(.red)

        Divider()

        Button(L10n.refreshStatus) { controller.refresh() }
        Button(L10n.quit) { NSApplication.shared.terminate(nil) }
    }
}
