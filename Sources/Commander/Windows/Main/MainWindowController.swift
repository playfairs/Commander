import AppKit

final class MainWindowController: NSWindowController {
    init() {
        let window = MainWindow()
        super.init(window: window)
        window.title = "Commander"
        window.center()
        window.setContentSize(NSSize(width: 1100, height: 700))
        window.toolbar = makeToolbar()
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "CommanderToolbar")
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        toolbar.sizeMode = .small
        return toolbar
    }
}

extension MainWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .back,
            .forward,
            .reveal,
            .flexibleSpace,
            .viewList,
            .viewGrid,
            .info,
            .newTab
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .back,
            .forward,
            .reveal,
            .flexibleSpace,
            .viewList,
            .viewGrid,
            .info,
            .newTab
        ]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .back:
            return toolbarItem(identifier: .back, image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back"), label: "Back")
        case .forward:
            return toolbarItem(identifier: .forward, image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward"), label: "Forward")
        case .reveal:
            return toolbarItem(identifier: .reveal, image: NSImage(systemSymbolName: "folder", accessibilityDescription: "Reveal"), label: "Reveal")
        case .viewList:
            return toolbarItem(identifier: .viewList, image: NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "List"), label: "List")
        case .viewGrid:
            return toolbarItem(identifier: .viewGrid, image: NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Grid"), label: "Grid")
        case .info:
            return toolbarItem(identifier: .info, image: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Info"), label: "Info")
        case .newTab:
            return toolbarItem(identifier: .newTab, image: NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab"), label: "New Tab")
        default:
            return nil
        }
    }

    private func toolbarItem(identifier: NSToolbarItem.Identifier, image: NSImage?, label: String) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.image = image
        item.label = label
        item.paletteLabel = label
        item.target = self
        item.action = #selector(toolbarAction(_:))
        return item
    }

    @objc private func toolbarAction(_ sender: NSToolbarItem) {
        guard let viewController = window?.contentViewController as? MainViewController else { return }
        viewController.handleToolbarAction(sender.itemIdentifier)
    }
}

extension NSToolbarItem.Identifier {
    static let back = NSToolbarItem.Identifier("CommanderToolbarBack")
    static let forward = NSToolbarItem.Identifier("CommanderToolbarForward")
    static let reveal = NSToolbarItem.Identifier("CommanderToolbarReveal")
    static let viewList = NSToolbarItem.Identifier("CommanderToolbarViewList")
    static let viewGrid = NSToolbarItem.Identifier("CommanderToolbarViewGrid")
    static let info = NSToolbarItem.Identifier("CommanderToolbarInfo")
    static let newTab = NSToolbarItem.Identifier("CommanderToolbarNewTab")
}
