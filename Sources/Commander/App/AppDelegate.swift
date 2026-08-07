import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private var windowController: MainWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = buildMainMenu()

    let session = SessionManager.currentSession()
    let controller = MainWindowController(session: session)
    controller.showWindow(nil)
    windowController = controller
    func tryLoadIcns(named name: String) -> NSImage? {
      let candidatePaths: [URL] = {
        var urls = [URL]()
        if let mainRes = Bundle.main.resourceURL {
          urls.append(
            mainRes.appendingPathComponent("Commander_Commander.bundle/")
              .appendingPathComponent("\(name).icns"))
          urls.append(
            mainRes.appendingPathComponent("Commander_Commander.bundle/Assets/Icons/icns")
              .appendingPathComponent("\(name).icns"))
          urls.append(
            mainRes.appendingPathComponent("Assets/Icons/icns")
              .appendingPathComponent("\(name).icns"))
        }

        let cwdPath = FileManager.default.currentDirectoryPath
        urls.append(
          URL(fileURLWithPath: cwdPath)
            .appendingPathComponent("Assets/Icons/icns")
            .appendingPathComponent("\(name).icns"))

        if let exe = Bundle.main.executableURL {
          var dir = exe.deletingLastPathComponent()
          for _ in 0..<6 {
            urls.append(
              dir.appendingPathComponent(
                "Contents/Resources/Commander_Commander.bundle/Assets/Icons/icns"
              )
              .appendingPathComponent("\(name).icns"))
            urls.append(
              dir.appendingPathComponent("Contents/Resources/Assets/Icons/icns")
                .appendingPathComponent("\(name).icns"))
            urls.append(
              dir.appendingPathComponent("Assets/Icons/icns")
                .appendingPathComponent("\(name).icns"))
            dir.deleteLastPathComponent()
          }
        }
        return urls
      }()

      for url in candidatePaths {
        if FileManager.default.fileExists(atPath: url.path), let img = NSImage(contentsOf: url) {
          return img
        }
      }
      return nil
    }

    let fm = FileManager.default
    let candidateDirs: [URL] = {
      var urls = [URL]()
      if let mainRes = Bundle.main.resourceURL {
        urls.append(mainRes.appendingPathComponent("Commander_Commander.bundle/Assets/Icons/icns"))
        urls.append(mainRes.appendingPathComponent("Assets/Icons/icns"))
      }
      urls.append(
        URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Assets/Icons/icns"))
      if let exe = Bundle.main.executableURL {
        var dir = exe.deletingLastPathComponent()
        for _ in 0..<6 {
          urls.append(
            dir.appendingPathComponent(
              "Contents/Resources/Commander_Commander.bundle/Assets/Icons/icns"))
          urls.append(dir.appendingPathComponent("Contents/Resources/Assets/Icons/icns"))
          urls.append(dir.appendingPathComponent("Assets/Icons/icns"))
          dir.deleteLastPathComponent()
        }
      }
      return urls
    }()

    for dir in candidateDirs {
      guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
      else { continue }
      for file in entries where file.pathExtension.lowercased() == "icns" {
        if let img = NSImage(contentsOf: file) {
          NSApp.applicationIconImage = img
          break
        }
      }
      if NSApp.applicationIconImage != nil { break }
    }

    // If nothing found and we attempted directories, leave default icon
    // ok so uhm this just DOESNT work

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
    mainMenu.addItem(fileMenuItem)

    let viewMenuItem = NSMenuItem()
    let viewMenu = NSMenu(title: "View")
    viewMenuItem.submenu = viewMenu
    let hiddenItem = viewMenu.addItem(
      withTitle: "Toggle Hidden Files", action: #selector(toggleHiddenFilesAction(_:)),
      keyEquivalent: ".")
    hiddenItem.keyEquivalentModifierMask = [.command, .shift]
    hiddenItem.target = self

    let goToItem = viewMenu.addItem(
      withTitle: "Go to Folder…", action: #selector(goToPathAction(_:)), keyEquivalent: "G")
    goToItem.keyEquivalentModifierMask = [.command, .shift]
    goToItem.target = self

    mainMenu.addItem(viewMenuItem)

    return mainMenu
  }
}

extension AppDelegate {
  @objc fileprivate func goToPathAction(_ sender: Any?) {
    rootViewController?.goToPath(nil)
  }

  @objc fileprivate func toggleHiddenFilesAction(_ sender: Any?) {
    rootViewController?.toggleHiddenFiles(sender)
  }

  fileprivate var rootViewController: MainViewController? {
    if let controller = windowController?.window?.contentViewController as? MainViewController {
      return controller
    }
    return NSApp.keyWindow?.contentViewController as? MainViewController
  }
}
