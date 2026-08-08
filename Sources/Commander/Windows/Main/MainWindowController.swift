import AppKit

@MainActor
final class MainWindowController: NSWindowController {
  private let toolbarDelegate: MainToolbar

  init(session: Session) {
    let contentViewController = MainViewController(session: session)
    toolbarDelegate = MainToolbar(target: contentViewController)
    let window = MainWindow(
      session: session, contentViewController: contentViewController,
      toolbar: toolbarDelegate.makeToolbar())
    super.init(window: window)
    window.contentViewController = contentViewController
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
