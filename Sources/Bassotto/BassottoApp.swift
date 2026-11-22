import SwiftUI

@main
struct BassottoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(stage: appDelegate.stage)
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let stage = StageController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        stage.start()
    }
}

private struct MenuContent: View {
    @Bindable var stage: StageController
    @State private var opensAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Button("Come here") { stage.callToCursor() }
        Button(stage.isVisible ? "Put to bed" : "Wake up") { stage.toggleVisible() }
        Toggle("Mischief (steals your cursor)", isOn: $stage.mischief)
        Divider()
        Toggle("Open at login", isOn: $opensAtLogin)
            .onChange(of: opensAtLogin) { _, enabled in
                opensAtLogin = LaunchAtLogin.set(enabled)
            }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
