import AppKit

enum MainToolbarItem: String, CaseIterable {
  case back
  case forward
  case reveal
  case viewList
  case viewGrid
  case info

  var identifier: NSToolbarItem.Identifier {
    NSToolbarItem.Identifier(rawValue)
  }

  var label: String {
    switch self {
    case .back: return "Back"
    case .forward: return "Forward"
    case .reveal: return "Reveal"
    case .viewList: return "List"
    case .viewGrid: return "Grid"
    case .info: return "Info"
    }
  }

  var imageName: String {
    switch self {
    case .back: return "chevron.left"
    case .forward: return "chevron.right"
    case .reveal: return "eye"
    case .viewList: return "list.bullet"
    case .viewGrid: return "square.grid.2x2"
    case .info: return "info.circle"
    }
  }
}

@MainActor
final class MainToolbar: NSObject, NSToolbarDelegate {
  private weak var target: AnyObject?

  init(target: AnyObject) {
    self.target = target
    super.init()
  }

  func makeToolbar() -> NSToolbar {
    let toolbar = NSToolbar(identifier: NSToolbar.Identifier("CommanderMainToolbar"))
    toolbar.delegate = self
    toolbar.displayMode = .iconOnly
    toolbar.allowsUserCustomization = false
    toolbar.showsBaselineSeparator = true
    toolbar.sizeMode = .regular
    return toolbar
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    MainToolbarItem.allCases.map { $0.identifier }
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [.flexibleSpace] + MainToolbarItem.allCases.map { $0.identifier } + [.flexibleSpace]
  }

  func toolbar(
    _ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    guard let item = MainToolbarItem(rawValue: itemIdentifier.rawValue) else { return nil }
    let toolbarItem = NSToolbarItem(itemIdentifier: item.identifier)
    toolbarItem.label = item.label
    toolbarItem.paletteLabel = item.label
    toolbarItem.toolTip = item.label
    toolbarItem.image = NSImage(
      systemSymbolName: item.imageName, accessibilityDescription: item.label)
    toolbarItem.target = target
    toolbarItem.action = #selector(MainViewController.handleToolbarItem(_:))
    return toolbarItem
  }
}
