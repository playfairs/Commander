import AppKit

@MainActor
final class MainWindow: NSWindow {
  init(session: Session, contentViewController: NSViewController, toolbar: NSToolbar) {
    let frame = NSRect(x: 0, y: 0, width: 1400, height: 900)
    super.init(
      contentRect: frame,
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false)

    self.title = session.label ?? "Commander"
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.toolbar = toolbar
    self.toolbarStyle = .unified
    self.contentViewController = contentViewController
    self.setFrameAutosaveName("MainWindow")
    self.center()
    self.makeKeyAndOrderFront(nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
