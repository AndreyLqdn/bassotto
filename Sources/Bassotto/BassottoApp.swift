import SwiftUI

@main
struct BassottoApp: App {
    var body: some Scene {
        MenuBarExtra("Bassotto", systemImage: "dog.fill") {
            Text("Woof. I live here now.")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
