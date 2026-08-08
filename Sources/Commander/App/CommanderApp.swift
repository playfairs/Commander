import SwiftUI

@main
struct CommanderApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup("Commander") {
      CommanderRootView()
        .frame(minWidth: 1100, minHeight: 700)
    }
    .defaultSize(width: 1100, height: 700)
    .windowStyle(.automatic)
  }
}

struct CommanderRootView: View {
  var body: some View {
    CommanderShellView(session: SessionManager.currentSession())
  }
}
