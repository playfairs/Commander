import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private var windowController: MainWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = buildMainMenu()

    let controller = MainWindowController()
    controller.showWindow(nil)
    windowController = controller
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  @objc func terminate(_ sender: Any?) {
    NSApp.terminate(sender)
  }

  private func buildMainMenu() -> NSMenu {
    let mainMenu = NSMenu()

    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenuItem.submenu = appMenu
    appMenu.addItem(
      withTitle: "About Commander",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    let quitItem = appMenu.addItem(
      withTitle: "Quit Commander", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    quitItem.target = NSApp
    mainMenu.addItem(appMenuItem)

    let fileMenuItem = NSMenuItem()
    let fileMenu = NSMenu(title: "File")
    fileMenuItem.submenu = fileMenu
    let goFolderItem = fileMenu.addItem(
      withTitle: "Go to Folder…", action: #selector(goToPathAction(_:)), keyEquivalent: "g")
    goFolderItem.target = self
    let quickSearchItem = fileMenu.addItem(
      withTitle: "Quick Search…", action: #selector(quickSearchAction(_:)), keyEquivalent: "s")
    quickSearchItem.target = self
    let fullSearchItem = fileMenu.addItem(
      withTitle: "Full Search…", action: #selector(fullSearchAction(_:)), keyEquivalent: "S")
    fullSearchItem.target = self
    mainMenu.addItem(fileMenuItem)

    let viewMenuItem = NSMenuItem()
    let viewMenu = NSMenu(title: "View")
    viewMenuItem.submenu = viewMenu
    let hiddenItem = viewMenu.addItem(
      withTitle: "Toggle Hidden Files", action: #selector(toggleHiddenFilesAction(_:)),
      keyEquivalent: ".")
    hiddenItem.keyEquivalentModifierMask = [.command, .shift]
    hiddenItem.target = self

    let paletteItem = viewMenu.addItem(
      withTitle: "Command Palette…", action: #selector(showCommandPaletteAction(_:)),
      keyEquivalent: "P")
    paletteItem.keyEquivalentModifierMask = [.command, .shift]
    paletteItem.target = self

    let goToItem = viewMenu.addItem(
      withTitle: "Go to Folder…", action: #selector(goToPathAction(_:)), keyEquivalent: "G")
    goToItem.keyEquivalentModifierMask = [.command, .shift]
    goToItem.target = self

    let fullSearchViewItem = viewMenu.addItem(
      withTitle: "Full Search…", action: #selector(fullSearchAction(_:)), keyEquivalent: "S")
    fullSearchViewItem.keyEquivalentModifierMask = [.command, .shift]
    fullSearchViewItem.target = self

    mainMenu.addItem(viewMenuItem)

    return mainMenu
  }
}

extension AppDelegate {
  @objc fileprivate func goToPathAction(_ sender: Any?) {
    rootViewController?.goToPath(nil)
  }

  @objc fileprivate func quickSearchAction(_ sender: Any?) {
    rootViewController?.quickSearch(nil)
  }

  @objc fileprivate func fullSearchAction(_ sender: Any?) {
    rootViewController?.fullSearch(nil)
  }

  @objc fileprivate func toggleHiddenFilesAction(_ sender: Any?) {
    rootViewController?.toggleHiddenFiles(nil)
  }

  @objc fileprivate func showCommandPaletteAction(_ sender: Any?) {
    rootViewController?.showCommandPalette()
  }

  fileprivate var rootViewController: MainViewController? {
    if let controller = windowController?.window?.contentViewController as? MainViewController {
      return controller
    }
    return NSApp.keyWindow?.contentViewController as? MainViewController
  }
}
