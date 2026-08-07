import AppKit

final class MainWindow: NSWindow {
  init(session: Session) {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    titlebarAppearsTransparent = true
    isReleasedWhenClosed = false
    center()
    contentViewController = MainViewController(session: session)
    if let label = session.label {
      title = "Commander"
      subtitle = label
    }
  }
}
