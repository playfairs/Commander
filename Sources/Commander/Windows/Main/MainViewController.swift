import AppKit
import Quartz
import UniformTypeIdentifiers

private func isDirectory(_ url: URL) -> Bool {
  var isDirectory: ObjCBool = false
  return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    && isDirectory.boolValue
}

private final class BrowserTableView: NSTableView {
  weak var browserPane: BrowserPaneViewController?

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 36, 76:  // KEY: Return, numpad Enter
      browserPane?.performEnterKeyAction()
    case 49:  // KEY: Space
      browserPane?.performQuickLookAction()
    case 117:  // KEY: Forward Delete
      browserPane?.goUpDirectory()
    case 51:  // KEY: Delete / Backspace
      if event.modifierFlags.contains(.command) {
        browserPane?.performPermanentDeleteAction()
      } else {
        browserPane?.performTrashAction()
      }
    default:
      super.keyDown(with: event)
    }
  }

  override func menu(for event: NSEvent) -> NSMenu? {
    let point = convert(event.locationInWindow, from: nil)
    let row = row(at: point)
    if row >= 0 {
      selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
      return browserPane?.contextMenuForSelectedItem()
    }
    return super.menu(for: event)
  }
}

private final class BrowserQuickLookDataSource: NSObject, QLPreviewPanelDataSource {
  var previewURLs: [URL] = []

  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    previewURLs.count
  }

  func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
    guard index >= 0, index < previewURLs.count else { return nil }
    return previewURLs[index] as NSURL
  }
}

@MainActor private protocol BrowserPaneDelegate: AnyObject {
  func browserPaneDidActivate(_ pane: BrowserPaneViewController)
  func browserPane(_ pane: BrowserPaneViewController, didUpdateStatus status: String)
}

final class MainViewController: NSViewController, NSTextFieldDelegate {
  private let splitController = NSSplitViewController()
  private let statusBar = NSTextField(labelWithString: "")
  private let statusSeparator = NSBox()
  private let statusContainer = NSView()
  private var folderSizeGenerationID = UUID()

  private let session: Session
  private var showHiddenFiles = false
  private weak var activePane: BrowserPaneViewController?
  private var popupOverlay: NSView?
  private var popupTextField: NSTextField?
  private var popupCompletion: ((String) -> Void)?

  init(session: Session) {
    self.session = session
    super.init(nibName: nil, bundle: nil)
  }

  convenience init() {
    self.init(session: Session(rootURL: FileManager.default.homeDirectoryForCurrentUser))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

    configureSplitController()
    configureStatusBar()

    statusContainer.translatesAutoresizingMaskIntoConstraints = false
    statusContainer.wantsLayer = true
    statusContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    statusContainer.addSubview(statusBar)

    let container = NSStackView(views: [splitController.view, statusSeparator, statusContainer])
    container.orientation = .vertical
    container.alignment = .width
    container.distribution = .fill
    container.spacing = 0
    container.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(container)

    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 1),
      container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      splitController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 320),
      splitController.view.widthAnchor.constraint(equalTo: container.widthAnchor),
      statusContainer.heightAnchor.constraint(equalToConstant: 28),
      statusBar.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 12),
      statusBar.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -12),
      statusBar.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
      statusSeparator.heightAnchor.constraint(equalToConstant: 1),
    ])

    splitController.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
    splitController.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    self.view = view
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupInitialBrowserSplit()
  }

  private func configureSplitController() {
    addChild(splitController)
    splitController.view.translatesAutoresizingMaskIntoConstraints = false
    splitController.splitView.isVertical = true
    splitController.splitView.dividerStyle = .thin
  }

  private func configureStatusBar() {
    statusSeparator.boxType = .custom
    statusSeparator.fillColor = NSColor.separatorColor
    statusSeparator.translatesAutoresizingMaskIntoConstraints = false

    statusBar.font = .systemFont(ofSize: 12)
    statusBar.textColor = .secondaryLabelColor
    statusBar.alignment = .left
    statusBar.lineBreakMode = .byTruncatingTail
    statusBar.translatesAutoresizingMaskIntoConstraints = false
    statusBar.backgroundColor = .clear
    statusBar.drawsBackground = false
    statusBar.isSelectable = false
    statusBar.cell?.usesSingleLineMode = true
    statusBar.cell?.wraps = false
  }

  private func setupInitialBrowserSplit() {
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    let desktopURL = BrowserPaneViewController.defaultDesktopURL

    let leftPane = BrowserPaneViewController(title: "Left Pane", rootURL: homeURL)
    let rightPane = BrowserPaneViewController(title: "Right Pane", rootURL: desktopURL)
    leftPane.delegate = self
    rightPane.delegate = self
    leftPane.showHiddenFiles = showHiddenFiles
    rightPane.showHiddenFiles = showHiddenFiles

    let leftSplit = NSSplitViewItem(viewController: leftPane)
    leftSplit.minimumThickness = 300
    leftSplit.canCollapse = false
    leftSplit.holdingPriority = .defaultLow
    leftSplit.preferredThicknessFraction = 0.5

    let rightSplit = NSSplitViewItem(viewController: rightPane)
    rightSplit.minimumThickness = 300
    rightSplit.canCollapse = false
    rightSplit.holdingPriority = .defaultLow
    rightSplit.preferredThicknessFraction = 0.5

    splitController.addSplitViewItem(leftSplit)
    splitController.addSplitViewItem(rightSplit)

    activePane = leftPane
    updateStatusBar()
  }

  func handleToolbarAction(_ identifier: NSToolbarItem.Identifier) {
    switch identifier {
    case .back:
      activePane?.goBack()
    case .forward:
      activePane?.goForward()
    case .reveal:
      activePane?.revealInFinder()
    case .viewList:
      activePane?.setListViewMode()
    case .viewGrid:
      activePane?.setIconViewMode()
    case .info:
      activePane?.showSelectedInfo()
    default:
      break
    }
    updateStatusBar()
  }

  @objc func goToPath(_ sender: Any?) {
    presentFinderGoToFolderPopup { [weak self] path in
      self?.goToPath(pathText: path)
    }
  }

  private func goToPath(pathText: String) {
    let expanded = NSString(string: pathText).expandingTildeInPath
    let url = URL(fileURLWithPath: expanded)
    guard isDirectory(url) else {
      showAlert(title: "Invalid Path", message: "\(pathText) is not a valid directory.")
      return
    }
    activePane?.goToPath(url)
  }

  @objc func toggleHiddenFiles(_ sender: Any? = nil) {
    showHiddenFiles.toggle()
    splitController.splitViewItems.forEach { item in
      if let pane = item.viewController as? BrowserPaneViewController {
        pane.showHiddenFiles = showHiddenFiles
        pane.reloadCurrentDirectory()
      }
    }
    updateStatusBar()
  }

  func updateStatusBar() {
    guard let pane = activePane else {
      statusBar.stringValue = "Ready"
      return
    }
    let baseText = pane.statusText
    if let label = session.label {
      statusBar.stringValue = "Session: \(label) — \(baseText)"
    } else {
      statusBar.stringValue = baseText
    }
  }

  private func promptForText(
    title: String, message: String, placeholder: String, completion: @escaping (String) -> Void
  ) {
    presentTextPopup(
      title: title, subtitle: message, placeholder: placeholder, acceptTitle: "OK",
      completion: completion)
  }

  private func showAlert(title: String, message: String) {
    presentMessagePopup(title: title, message: message)
  }

  private func presentTextPopup(
    title: String, subtitle: String, placeholder: String, acceptTitle: String,
    completion: @escaping (String) -> Void
  ) {
    removePopupOverlay()

    let overlay = NSView()
    overlay.wantsLayer = true
    overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.32).cgColor
    overlay.translatesAutoresizingMaskIntoConstraints = false

    let panel = NSVisualEffectView()
    panel.material = .popover
    panel.state = .active
    panel.wantsLayer = true
    panel.layer?.cornerRadius = 18
    panel.translatesAutoresizingMaskIntoConstraints = false

    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
    titleLabel.textColor = .white
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    let subtitleLabel = NSTextField(labelWithString: subtitle)
    subtitleLabel.font = .systemFont(ofSize: 12)
    subtitleLabel.textColor = .secondaryLabelColor
    subtitleLabel.lineBreakMode = .byWordWrapping
    subtitleLabel.maximumNumberOfLines = 2
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

    let textField = NSTextField(string: "")
    textField.placeholderString = placeholder
    textField.controlSize = .regular
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.target = self
    textField.action = #selector(popupTextFieldAction(_:))

    let buttonStack = NSStackView()
    buttonStack.orientation = .horizontal
    buttonStack.spacing = 10
    buttonStack.translatesAutoresizingMaskIntoConstraints = false

    let cancelButton = NSButton(
      title: "Cancel", target: self, action: #selector(popupCancelAction(_:)))
    cancelButton.bezelStyle = .rounded
    let okButton = NSButton(
      title: acceptTitle, target: self, action: #selector(popupConfirmAction(_:)))
    okButton.bezelStyle = .rounded

    buttonStack.addArrangedSubview(cancelButton)
    buttonStack.addArrangedSubview(okButton)

    panel.addSubview(titleLabel)
    panel.addSubview(subtitleLabel)
    panel.addSubview(textField)
    panel.addSubview(buttonStack)
    overlay.addSubview(panel)
    view.addSubview(overlay)

    NSLayoutConstraint.activate([
      overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      overlay.topAnchor.constraint(equalTo: view.topAnchor),
      overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      panel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      panel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -24),
      panel.widthAnchor.constraint(equalToConstant: 520),
      titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 24),
      titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
      titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
      subtitleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
      subtitleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
      textField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
      textField.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
      textField.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
      textField.heightAnchor.constraint(equalToConstant: 30),
      buttonStack.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 16),
      buttonStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
      buttonStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -20),
    ])

    popupOverlay = overlay
    popupTextField = textField
    popupCompletion = completion

    view.window?.makeFirstResponder(textField)
  }

  private func presentFinderGoToFolderPopup(completion: @escaping (String) -> Void) {
    let alert = NSAlert()
    alert.messageText = "Go to Folder"
    alert.informativeText = "Enter the path of the folder you want to open."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Go")
    alert.addButton(withTitle: "Cancel")

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
    textField.placeholderString = ""
    textField.font = .systemFont(ofSize: 13)
    textField.bezelStyle = .roundedBezel
    textField.focusRingType = .default
    alert.accessoryView = textField

    if let window = view.window {
      alert.beginSheetModal(for: window) { response in
        if response == .alertFirstButtonReturn {
          completion(textField.stringValue)
        }
      }
      window.makeFirstResponder(textField)
    } else {
      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
        completion(textField.stringValue)
      }
    }
  }

  private func presentMessagePopup(title: String, message: String) {
    removePopupOverlay()

    let overlay = NSView()
    overlay.wantsLayer = true
    overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.32).cgColor
    overlay.translatesAutoresizingMaskIntoConstraints = false

    let panel = NSVisualEffectView()
    panel.material = .popover
    panel.state = .active
    panel.wantsLayer = true
    panel.layer?.cornerRadius = 18
    panel.translatesAutoresizingMaskIntoConstraints = false

    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
    titleLabel.textColor = .white
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    let messageLabel = NSTextField(labelWithString: message)
    messageLabel.font = .systemFont(ofSize: 12)
    messageLabel.textColor = .secondaryLabelColor
    messageLabel.lineBreakMode = .byWordWrapping
    messageLabel.maximumNumberOfLines = 3
    messageLabel.translatesAutoresizingMaskIntoConstraints = false

    let okButton = NSButton(title: "OK", target: self, action: #selector(popupCancelAction(_:)))
    okButton.bezelStyle = .rounded
    okButton.translatesAutoresizingMaskIntoConstraints = false

    panel.addSubview(titleLabel)
    panel.addSubview(messageLabel)
    panel.addSubview(okButton)
    overlay.addSubview(panel)
    view.addSubview(overlay)

    NSLayoutConstraint.activate([
      overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      overlay.topAnchor.constraint(equalTo: view.topAnchor),
      overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      panel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      panel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      panel.widthAnchor.constraint(equalToConstant: 420),
      titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 24),
      titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
      titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
      messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
      messageLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
      messageLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
      okButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
      okButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
      okButton.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -20),
    ])

    popupOverlay = overlay
  }

  private func removePopupOverlay() {
    popupOverlay?.removeFromSuperview()
    popupOverlay = nil
    popupTextField = nil
    popupCompletion = nil
  }

  @objc private func popupTextFieldAction(_ sender: NSTextField) {
    popupConfirm(with: sender.stringValue)
  }

  @objc private func popupConfirmAction(_ sender: Any?) {
    popupConfirm(with: popupTextField?.stringValue ?? "")
  }

  @objc private func popupCancelAction(_ sender: Any?) {
    removePopupOverlay()
  }

  private func popupConfirm(with text: String) {
    removePopupOverlay()
    popupCompletion?(text)
  }
}

@MainActor extension MainViewController: BrowserPaneDelegate {
  fileprivate func browserPaneDidActivate(_ pane: BrowserPaneViewController) {
    activePane = pane
    updateStatusBar()
  }

  fileprivate func browserPane(_ pane: BrowserPaneViewController, didUpdateStatus status: String) {
    if activePane === pane {
      updateStatusBar()
    }
  }
}

private final class BrowserPaneViewController: NSViewController {
  weak var delegate: BrowserPaneDelegate?

  let titleText: String
  private(set) var currentURL: URL
  private var history: [URL] = []
  private var historyIndex: Int = 0
  private var items: [DirectoryItem] = []
  private let quickLookDataSource = BrowserQuickLookDataSource()
  private var statusMessage: String? {
    didSet { delegate?.browserPane(self, didUpdateStatus: statusText) }
  }
  private var progressTimer: DispatchSourceTimer?
  private var folderSizeGenerationID = UUID()

  var showHiddenFiles = false

  private let pathControl = NSPathControl()
  private let tableView = BrowserTableView()
  private let scrollView = NSScrollView()
  private let backButton = NSButton(
    title: "",
    image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back") ?? NSImage(),
    target: nil, action: nil)
  private let forwardButton = NSButton(
    title: "",
    image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
      ?? NSImage(), target: nil, action: nil)
  private let upButton = NSButton(
    title: "",
    image: NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Up") ?? NSImage(),
    target: nil, action: nil)

  init(title: String, rootURL: URL) {
    self.titleText = title
    self.currentURL = rootURL
    super.init(nibName: nil, bundle: nil)
    self.title = title
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

    configureNavigationButtons()
    configurePathControl()
    setupTableView()

    let actionButtons = NSStackView(views: [
      addActionButton(
        title: "New Folder", symbolName: "folder.badge.plus", action: #selector(createNewFolder)),
      addActionButton(
        title: "Duplicate", symbolName: "doc.on.doc", action: #selector(duplicateSelectedItem)),
      addActionButton(
        title: "Open in Terminal", symbolName: "terminal", action: #selector(openInTerminal)),
    ])
    actionButtons.orientation = .horizontal
    actionButtons.alignment = .centerY
    actionButtons.spacing = 6
    actionButtons.translatesAutoresizingMaskIntoConstraints = false

    let navigationRow = NSStackView(views: [
      backButton, forwardButton, upButton, pathControl, actionButtons,
    ])
    navigationRow.orientation = .horizontal
    navigationRow.alignment = .centerY
    navigationRow.spacing = 8
    navigationRow.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
    navigationRow.translatesAutoresizingMaskIntoConstraints = false

    let container = NSStackView(views: [navigationRow, scrollView])
    container.orientation = .vertical
    container.alignment = .width
    container.spacing = 0
    container.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(container)

    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 1),
      container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 210),
    ])

    self.view = view
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    loadDirectory(currentURL, replaceHistory: true)
  }

  private func configureNavigationButtons() {
    [backButton, forwardButton, upButton].forEach {
      $0.bezelStyle = .texturedRounded
      $0.controlSize = .small
      $0.isBordered = true
      $0.translatesAutoresizingMaskIntoConstraints = false
    }

    backButton.target = self
    backButton.action = #selector(goBack)
    forwardButton.target = self
    forwardButton.action = #selector(goForward)
    upButton.target = self
    upButton.action = #selector(goUp)
  }

  private func addActionButton(title: String, symbolName: String, action: Selector) -> NSButton {
    let button = NSButton(title: title, target: self, action: action)
    button.bezelStyle = .rounded
    button.controlSize = .small
    button.font = .systemFont(ofSize: 11)
    button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
    button.imagePosition = .imageLeading
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }

  private func configurePathControl() {
    pathControl.controlSize = .small
    pathControl.url = currentURL
    pathControl.pathStyle = .popUp
    pathControl.target = self
    pathControl.action = #selector(pathSelected(_:))
    pathControl.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setupTableView() {
    let nameColumn = NSTableColumn(identifier: .name)
    nameColumn.title = "Name"
    nameColumn.width = 300
    nameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)

    let kindColumn = NSTableColumn(identifier: .kind)
    kindColumn.title = "Kind"
    kindColumn.width = 140
    kindColumn.sortDescriptorPrototype = NSSortDescriptor(key: "kind", ascending: true)

    let sizeColumn = NSTableColumn(identifier: .size)
    sizeColumn.title = "Size"
    sizeColumn.width = 100
    sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "sizeValue", ascending: true)

    let modifiedColumn = NSTableColumn(identifier: .modified)
    modifiedColumn.title = "Modified"
    modifiedColumn.width = 160
    modifiedColumn.sortDescriptorPrototype = NSSortDescriptor(key: "modifiedDate", ascending: true)

    tableView.addTableColumn(nameColumn)
    tableView.addTableColumn(kindColumn)
    tableView.addTableColumn(sizeColumn)
    tableView.addTableColumn(modifiedColumn)
    tableView.headerView = NSTableHeaderView()
    tableView.allowsColumnReordering = false
    tableView.allowsColumnResizing = true
    tableView.usesAlternatingRowBackgroundColors = true
    tableView.rowHeight = 28
    tableView.selectionHighlightStyle = .regular
    tableView.delegate = self
    tableView.dataSource = self
    tableView.allowsMultipleSelection = false
    tableView.allowsEmptySelection = true
    tableView.target = self
    tableView.doubleAction = #selector(handleDoubleClick)
    tableView.registerForDraggedTypes([.fileURL])
    tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
    tableView.focusRingType = .none
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.browserPane = self

    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.drawsBackground = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
  }

  fileprivate func loadDirectory(_ url: URL, replaceHistory: Bool) {
    guard isDirectory(url) else { return }
    do {
      let options: FileManager.DirectoryEnumerationOptions =
        showHiddenFiles ? [] : [.skipsHiddenFiles]
      let rawItems = try FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [
          .isDirectoryKey, .contentTypeKey, .fileSizeKey, .contentModificationDateKey,
        ], options: options)
      let filtered = rawItems.filter { showHiddenFiles || !$0.lastPathComponent.hasPrefix(".") }
      let directoryItems = filtered.map { DirectoryItem(url: $0) }
      items = directoryItems
      sortItems()

      if let parentURL = parentURL(for: url) {
        items.insert(DirectoryItem.parentItem(for: parentURL), at: 0)
      }

      currentURL = url
      let generationID = UUID()
      folderSizeGenerationID = generationID
      loadFolderSizesIfNeeded(using: generationID)

      if replaceHistory {
        history = [url]
        historyIndex = 0
      } else {
        history = Array(history.prefix(historyIndex + 1)) + [url]
        historyIndex += 1
      }
      updateNavigationState()
    } catch {
      items = []
      updateNavigationState()
    }
  }

  fileprivate func reloadCurrentDirectory() {
    loadDirectory(currentURL, replaceHistory: true)
  }

  private func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }

  @objc fileprivate func goBack() {
    guard historyIndex > 0 else { return }
    historyIndex -= 1
    loadDirectory(history[historyIndex], replaceHistory: false)
  }

  @objc fileprivate func goForward() {
    guard historyIndex + 1 < history.count else { return }
    historyIndex += 1
    loadDirectory(history[historyIndex], replaceHistory: false)
  }

  @objc fileprivate func goUp() {
    guard let parent = parentURL(for: currentURL) else { return }
    loadDirectory(parent, replaceHistory: false)
  }

  fileprivate func goToPath(_ url: URL) {
    loadDirectory(url, replaceHistory: false)
  }

  fileprivate func revealInFinder() {
    NSWorkspace.shared.activateFileViewerSelecting([currentURL])
  }

  fileprivate func setListViewMode() {
    tableView.rowHeight = 28
    tableView.reloadData()
  }

  fileprivate func setIconViewMode() {
    tableView.rowHeight = 70
    tableView.reloadData()
  }

  fileprivate var selectedItem: DirectoryItem? {
    let row = tableView.selectedRow
    guard row >= 0, row < items.count else { return nil }
    return items[row]
  }

  fileprivate var statusText: String {
    if let statusMessage { return statusMessage }
    let name = currentURL.lastPathComponent.isEmpty ? currentURL.path : currentURL.lastPathComponent
    return "\(items.count) items — \(name)"
  }

  private func startProgressStatus(_ baseMessage: String) {
    stopProgressStatus()
    DispatchQueue.main.async { [weak self] in
      self?.statusMessage = baseMessage
    }

    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
    var dotCount = 0
    timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
    timer.setEventHandler { [weak self] in
      guard let self = self else { return }
      dotCount = (dotCount + 1) % 4
      self.statusMessage = baseMessage + String(repeating: ".", count: dotCount)
    }
    timer.resume()
    progressTimer = timer
  }

  private func stopProgressStatus() {
    progressTimer?.cancel()
    progressTimer = nil
    DispatchQueue.main.async { [weak self] in
      self?.statusMessage = nil
    }
  }

  @objc fileprivate func showSelectedInfo() {
    let url = selectedItem?.url ?? currentURL
    showFinderInfo(for: url)
  }

  private func showFinderInfo(for url: URL) {
    let metadataString = Metadata.formattedMetadata(for: url)

    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 320))
    textView.isEditable = false
    textView.isSelectable = true
    textView.string = metadataString
    textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    textView.backgroundColor = .textBackgroundColor

    let scrollView = NSScrollView(frame: textView.frame)
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.borderType = .bezelBorder

    let alert = NSAlert()
    alert.messageText = "Metadata for \(url.lastPathComponent)"
    alert.informativeText = ""
    alert.alertStyle = .informational
    alert.accessoryView = scrollView
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  fileprivate func search(query: String, fullSearch: Bool) {
    let searchQuery = SearchQuery(term: query, fullSearch: fullSearch)
    Task { [weak self] in
      guard let self = self else { return }
      let matches = await SearchController.search(
        query: searchQuery, from: self.currentURL, showHiddenFiles: self.showHiddenFiles)
      let description = fullSearch ? "Full search" : "Quick search"
      if matches.isEmpty {
        self.presentSearchResults(title: description, message: "No matches found for \(query).")
      } else {
        let firstPaths = matches.prefix(6).map { $0.path }.joined(separator: "\n")
        self.presentSearchResults(
          title: description, message: "Found \(matches.count) matches:\n\n\(firstPaths)")
      }
    }
  }

  private func presentSearchResults(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  private func updateNavigationState() {
    backButton.isEnabled = historyIndex > 0
    forwardButton.isEnabled = historyIndex + 1 < history.count
    upButton.isEnabled = parentURL(for: currentURL) != nil
    pathControl.url = currentURL
    tableView.reloadData()
    delegate?.browserPane(self, didUpdateStatus: statusText)
  }

  private func activatePane() {
    delegate?.browserPaneDidActivate(self)
  }

  private func parentURL(for url: URL) -> URL? {
    let parent = url.deletingLastPathComponent()
    if parent.path == url.path { return nil }
    if url.path == "/" { return nil }
    if url.pathComponents.count == 3 && url.pathComponents[1] == "Volumes" { return nil }
    return parent
  }

  @objc private func pathSelected(_ sender: NSPathControl) {
    let selectedURL = sender.clickedPathItem?.url ?? sender.url
    guard let url = selectedURL else { return }
    loadDirectory(url, replaceHistory: false)
    activatePane()
  }

  @objc private func handleDoubleClick() {
    let row = tableView.clickedRow
    guard row >= 0, row < items.count else { return }
    let item = items[row]
    if item.isParent {
      goUp()
      return
    }
    if item.isDirectory {
      loadDirectory(item.url, replaceHistory: false)
    } else {
      NSWorkspace.shared.open(item.url)
    }
    activatePane()
  }

  fileprivate func performEnterKeyAction() {
    guard let item = selectedItem else { return }
    if item.isParent {
      goUp()
    } else if item.isDirectory {
      loadDirectory(item.url, replaceHistory: false)
    } else {
      renameItem(item)
    }
    activatePane()
  }

  @objc fileprivate func performQuickLookAction() {
    guard let item = selectedItem, !item.isParent else { return }
    quickLookDataSource.previewURLs = [item.url]
    if let panel = QLPreviewPanel.shared() {
      panel.dataSource = quickLookDataSource
      panel.makeKeyAndOrderFront(nil)
    }
  }

  fileprivate func goUpDirectory() {
    goUp()
  }

  @objc fileprivate func createNewFolder() {
    let alert = NSAlert()
    alert.messageText = "Create Folder"
    alert.informativeText = "Choose a name for the new folder."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")

    let textField = NSTextField(string: "New Folder")
    textField.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
    alert.accessoryView = textField
    alert.window.initialFirstResponder = textField

    if alert.runModal() == .alertFirstButtonReturn {
      let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      do {
        let folderURL = try FileSystemOperations.createFolder(named: name, in: currentURL)
        loadDirectory(currentURL, replaceHistory: false)
        if let window = view.window {
          NSWorkspace.shared.selectFile(folderURL.path, inFileViewerRootedAtPath: currentURL.path)
          window.makeFirstResponder(tableView)
        }
      } catch {
        presentErrorAlert("Unable to create folder.", error: error)
      }
    }
  }

  @objc fileprivate func duplicateSelectedItem() {
    guard let item = selectedItem, !item.isParent else { return }
    do {
      let duplicatedURL = try FileSystemOperations.duplicateItem(at: item.url, in: currentURL)
      loadDirectory(currentURL, replaceHistory: false)
      NSWorkspace.shared.selectFile(duplicatedURL.path, inFileViewerRootedAtPath: currentURL.path)
    } catch {
      presentErrorAlert("Unable to duplicate item.", error: error)
    }
  }

  @objc fileprivate func openInTerminal() {
    let targetURL = selectedItem?.url ?? currentURL
    let escapedPath = targetURL.path.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let script = "tell application \"Terminal\" to do script \"cd \\\"\(escapedPath)\\\"\""
    if let appleScript = NSAppleScript(source: script) {
      var errorInfo: NSDictionary?
      appleScript.executeAndReturnError(&errorInfo)
      if errorInfo != nil {
        presentErrorAlert("Unable to open Terminal at the selected location.", error: nil)
      }
    }
  }

  @objc fileprivate func performTrashAction() {
    guard let item = selectedItem, !item.isParent else { return }
    do {
      try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
      reloadCurrentDirectory()
    } catch {
      presentErrorAlert("Unable to move item to Trash.", error: error)
    }
  }

  @objc fileprivate func performPermanentDeleteAction() {
    guard let item = selectedItem, !item.isParent else { return }
    let alert = NSAlert()
    alert.messageText = "Delete \(item.name) immediately?"
    alert.informativeText = "This cannot be undone."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Delete")
    alert.addButton(withTitle: "Cancel")
    if alert.runModal() == .alertFirstButtonReturn {
      do {
        try FileManager.default.removeItem(at: item.url)
        reloadCurrentDirectory()
      } catch {
        presentErrorAlert("Unable to delete item.", error: error)
      }
    }
  }

  func tableView(
    _ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int,
    proposedDropOperation dropOperation: NSTableView.DropOperation
  ) -> NSDragOperation {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    if info.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: options) {
      return .copy
    }
    return []
  }

  func tableView(
    _ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int,
    dropOperation: NSTableView.DropOperation
  ) -> Bool {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    guard
      let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options)
        as? [URL], !urls.isEmpty
    else {
      return false
    }
    return handleDrop(urls: urls)
  }

  private enum DropAction {
    case copy
    case move
  }

  private func handleDrop(urls: [URL]) -> Bool {
    guard let (action, names) = promptForDropAction(urls: urls) else { return false }
    do {
      try performDrop(urls: urls, action: action, names: names)
      let sourceFolders = urls.map { $0.deletingLastPathComponent() }
      reloadCurrentDirectory()
      if action == .move {
        reloadSiblingPanesAfterMove(from: sourceFolders)
      }
      playSuccessSound()
      return true
    } catch {
      presentErrorAlert("Unable to complete drag-and-drop operation.", error: error)
      return false
    }
  }

  private func promptForDropAction(urls: [URL]) -> (DropAction, [String]?)? {
    let alert = NSAlert()
    alert.messageText = urls.count == 1 ? "Copy or Move file?" : "Copy or Move files?"
    alert.informativeText =
      urls.count == 1
      ? "Choose whether to copy or move the file into this folder, and provide a new name."
      : "Choose whether to copy or move these files into this folder. Names will remain unchanged."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Copy")
    alert.addButton(withTitle: "Move")
    alert.addButton(withTitle: "Cancel")

    var nameField: NSTextField?
    if urls.count == 1 {
      let field = NSTextField(string: urls[0].lastPathComponent)
      field.placeholderString = "Enter new name"
      field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
      alert.accessoryView = field
      alert.window.initialFirstResponder = field
      nameField = field
    }

    let result = alert.runModal()
    switch result {
    case .alertFirstButtonReturn:
      let name =
        urls.count == 1
        ? nameField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) : nil
      let names = urls.count == 1 ? [name ?? urls[0].lastPathComponent] : nil
      return (.copy, names)
    case .alertSecondButtonReturn:
      let name =
        urls.count == 1
        ? nameField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) : nil
      let names = urls.count == 1 ? [name ?? urls[0].lastPathComponent] : nil
      return (.move, names)
    default:
      return nil
    }
  }

  private func performDrop(urls: [URL], action: DropAction, names: [String]?) throws {
    for (index, sourceURL) in urls.enumerated() {
      let destinationName =
        names?.indices.contains(index) == true ? names![index] : sourceURL.lastPathComponent
      let destinationURL = uniqueDestinationURL(
        for: currentURL.appendingPathComponent(destinationName))
      switch action {
      case .copy:
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
      case .move:
        if sourceURL == destinationURL { continue }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
      }
    }
  }

  private func uniqueDestinationURL(for url: URL) -> URL {
    var destination = url
    let originalName = url.deletingPathExtension().lastPathComponent
    let extensionPart = url.pathExtension
    var suffix = 1
    while FileManager.default.fileExists(atPath: destination.path) {
      let candidate =
        extensionPart.isEmpty
        ? "\(originalName) \(suffix)" : "\(originalName) \(suffix).\(extensionPart)"
      destination = url.deletingLastPathComponent().appendingPathComponent(candidate)
      suffix += 1
    }
    return destination
  }

  @objc fileprivate func compressSelectedItem() {
    guard let item = selectedItem, !item.isParent else { return }
    let sourceURL = item.url
    let parentURL = sourceURL.deletingLastPathComponent()
    let archiveName = sourceURL.lastPathComponent + ".zip"
    let destinationURL = uniqueDestinationURL(for: parentURL.appendingPathComponent(archiveName))
    let baseStatus = "Compressing \(item.name)"

    startProgressStatus(baseStatus)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
      process.currentDirectoryURL = parentURL
      process.arguments =
        item.isDirectory
        ? ["-r", destinationURL.path, sourceURL.lastPathComponent]
        : [destinationURL.path, sourceURL.lastPathComponent]

      let outputPipe = Pipe()
      process.standardOutput = outputPipe
      let errorPipe = Pipe()
      process.standardError = errorPipe
      outputPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard
          let line = String(data: data, encoding: .utf8)?.trimmingCharacters(
            in: .whitespacesAndNewlines),
          !line.isEmpty
        else { return }
        DispatchQueue.main.async { [weak self] in
          self?.statusMessage = "Compressing \(item.name): \(line)"
        }
      }

      var commandError: Error?
      var commandMessage: String?
      do {
        try process.run()
        process.waitUntilExit()
        outputPipe.fileHandleForReading.readabilityHandler = nil
        if process.terminationStatus != 0 {
          let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
          commandMessage = String(data: errorData, encoding: .utf8) ?? "Unable to compress item."
        }
      } catch {
        commandError = error
      }

      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.stopProgressStatus()
        if let error = commandError {
          self.presentErrorAlert("Unable to compress item.", error: error)
          return
        }
        if let message = commandMessage {
          self.presentErrorAlert(
            "Unable to compress item.",
            error: NSError(
              domain: "Commander", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
          return
        }
        self.reloadCurrentDirectory()
      }
    }
  }

  @objc fileprivate func gunzipSelectedItem() {
    guard let item = selectedItem, !item.isParent,
      item.url.pathExtension.lowercased() == "gz"
    else {
      return
    }

    let sourceURL = item.url
    let outputURL = uniqueDestinationURL(for: sourceURL.deletingPathExtension())
    let baseStatus = "Gunzipping \(item.name)"

    startProgressStatus(baseStatus)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
      process.arguments = ["-dc", sourceURL.path]

      let outputPipe = Pipe()
      process.standardOutput = outputPipe
      let errorPipe = Pipe()
      process.standardError = errorPipe

      var commandError: Error?
      var commandMessage: String?
      do {
        try process.run()
        process.waitUntilExit()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
          let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
          commandMessage = String(data: errorData, encoding: .utf8) ?? "Unable to gunzip item."
        } else {
          try data.write(to: outputURL)
        }
      } catch {
        commandError = error
      }

      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.stopProgressStatus()
        if let error = commandError {
          self.presentErrorAlert("Unable to gunzip item.", error: error)
          return
        }
        if let message = commandMessage {
          self.presentErrorAlert(
            "Unable to gunzip item.",
            error: NSError(
              domain: "Commander", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
          return
        }
        self.reloadCurrentDirectory()
      }
    }
  }

  @objc fileprivate func copySelectedItemPath() {
    guard let item = selectedItem, !item.isParent else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(item.url.path, forType: .string)
  }

  private func playSuccessSound() {
    // Prefer the 'Pop' sound for successful file moves/copies (more like Finder)
    // I will prob just drop using this bc it seems too much like Finder if I do this
    // which basically defeats the purpose of using a different app..
    if let sound = NSSound(named: NSSound.Name("Pop")) {
      sound.play()
    } else if let sound = NSSound(named: NSSound.Name("Funk")) {
      sound.play()
    } else {
      // As a last resort, do nothing instead of playing the error beep
    }
  }

  private func reloadSiblingPanesAfterMove(from sourceFolders: [URL]) {
    let uniqueSources = Array(Set(sourceFolders))
    view.window?.contentViewController?.children.forEach { controller in
      if let pane = controller as? BrowserPaneViewController, pane !== self,
        uniqueSources.contains(pane.currentURL)
      {
        pane.reloadCurrentDirectory()
      }
    }
  }

  @objc fileprivate func openSelectedItem() {
    guard let item = selectedItem else { return }
    if item.isParent {
      goUp()
    } else if item.isDirectory {
      loadDirectory(item.url, replaceHistory: false)
    } else {
      NSWorkspace.shared.open(item.url)
    }
    activatePane()
  }

  @objc fileprivate func revealSelectedItemInFinder() {
    guard let item = selectedItem, !item.isParent else { return }
    NSWorkspace.shared.activateFileViewerSelecting([item.url])
  }

  @objc fileprivate func renameSelectedItem() {
    guard let item = selectedItem, !item.isParent else { return }
    renameItem(item)
  }

  fileprivate func contextMenuForSelectedItem() -> NSMenu? {
    guard let item = selectedItem else { return nil }
    let menu = NSMenu()
    let openItem = NSMenuItem(title: "Open", action: #selector(openSelectedItem), keyEquivalent: "")
    openItem.target = self
    menu.addItem(openItem)
    let quickLookItem = NSMenuItem(
      title: "Quick Look \(item.name)", action: #selector(performQuickLookAction), keyEquivalent: ""
    )
    quickLookItem.target = self
    menu.addItem(quickLookItem)
    let renameItem = NSMenuItem(
      title: "Rename", action: #selector(renameSelectedItem), keyEquivalent: "")
    renameItem.target = self
    menu.addItem(renameItem)
    let duplicateItem = NSMenuItem(
      title: "Duplicate", action: #selector(duplicateSelectedItem), keyEquivalent: "")
    duplicateItem.target = self
    menu.addItem(duplicateItem)
    let compressItem = NSMenuItem(
      title: "Compress", action: #selector(compressSelectedItem), keyEquivalent: "")
    compressItem.target = self
    menu.addItem(compressItem)
    let gunzipItem = NSMenuItem(
      title: "Gunzip", action: #selector(gunzipSelectedItem), keyEquivalent: "")
    gunzipItem.target = self
    gunzipItem.isEnabled = item.url.pathExtension.lowercased() == "gz"
    menu.addItem(gunzipItem)
    let newFolderItem = NSMenuItem(
      title: "New Folder", action: #selector(createNewFolder), keyEquivalent: "")
    newFolderItem.target = self
    menu.addItem(newFolderItem)
    let terminalItem = NSMenuItem(
      title: "Open in Terminal", action: #selector(openInTerminal), keyEquivalent: "")
    terminalItem.target = self
    menu.addItem(terminalItem)
    menu.addItem(NSMenuItem.separator())
    let showInFinderItem = NSMenuItem(
      title: "Show in Finder", action: #selector(revealSelectedItemInFinder), keyEquivalent: "")
    showInFinderItem.target = self
    menu.addItem(showInFinderItem)
    let copyPathItem = NSMenuItem(
      title: "Copy Path", action: #selector(copySelectedItemPath), keyEquivalent: "")
    copyPathItem.target = self
    menu.addItem(copyPathItem)
    let trashItem = NSMenuItem(
      title: "Move to Trash", action: #selector(performTrashAction), keyEquivalent: "")
    trashItem.target = self
    menu.addItem(trashItem)
    let deleteItem = NSMenuItem(
      title: "Delete Immediately", action: #selector(performPermanentDeleteAction),
      keyEquivalent: "")
    deleteItem.target = self
    menu.addItem(deleteItem)
    menu.addItem(NSMenuItem.separator())
    let infoItem = NSMenuItem(
      title: "Get Info", action: #selector(showSelectedInfo), keyEquivalent: "")
    infoItem.target = self
    menu.addItem(infoItem)
    return menu
  }

  private func sortItems() {
    guard !tableView.sortDescriptors.isEmpty else { return }
    items.sort { lhs, rhs in
      for descriptor in tableView.sortDescriptors {
        let result = compare(lhs, rhs, by: descriptor)
        if result != .orderedSame {
          return descriptor.ascending ? result == .orderedAscending : result == .orderedDescending
        }
      }
      return false
    }
  }

  private func compare(_ lhs: DirectoryItem, _ rhs: DirectoryItem, by descriptor: NSSortDescriptor)
    -> ComparisonResult
  {
    if lhs.isParent != rhs.isParent {
      return lhs.isParent ? .orderedAscending : .orderedDescending
    }

    switch descriptor.key {
    case "name":
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
    case "kind":
      return lhs.kind.localizedCaseInsensitiveCompare(rhs.kind)
    case "sizeValue":
      return compareOptionalInt(lhs.sizeValue, rhs.sizeValue)
    case "modifiedDate":
      return compareOptionalDate(lhs.modifiedDate, rhs.modifiedDate)
    default:
      return .orderedSame
    }
  }

  private func compareOptionalInt(_ lhs: Int64?, _ rhs: Int64?) -> ComparisonResult {
    switch (lhs, rhs) {
    case let (l?, r?):
      return l < r ? .orderedAscending : (l > r ? .orderedDescending : .orderedSame)
    case (nil, nil):
      return .orderedSame
    case (nil, _):
      return .orderedAscending
    case (_, nil):
      return .orderedDescending
    }
  }

  private func compareOptionalDate(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
    switch (lhs, rhs) {
    case let (l?, r?):
      return l < r ? .orderedAscending : (l > r ? .orderedDescending : .orderedSame)
    case (nil, nil):
      return .orderedSame
    case (nil, _):
      return .orderedAscending
    case (_, nil):
      return .orderedDescending
    }
  }

  private func renameItem(_ item: DirectoryItem) {
    let alert = NSAlert()
    alert.messageText = "Rename"
    alert.informativeText = "Enter a new name for \(item.name):"
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Rename")
    alert.addButton(withTitle: "Cancel")

    let textField = NSTextField(string: item.name)
    textField.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
    alert.accessoryView = textField
    alert.window.initialFirstResponder = textField

    if alert.runModal() == .alertFirstButtonReturn {
      let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !newName.isEmpty else { return }
      let destination = item.url.deletingLastPathComponent().appendingPathComponent(newName)
      do {
        try FileManager.default.moveItem(at: item.url, to: destination)
        reloadCurrentDirectory()
      } catch {
        presentErrorAlert("Unable to rename item.", error: error)
      }
    }
  }

  private func presentErrorAlert(_ message: String, error: Error?) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = error?.localizedDescription ?? ""
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
}

extension BrowserPaneViewController: NSTableViewDataSource, NSTableViewDelegate {
  func numberOfRows(in tableView: NSTableView) -> Int {
    items.count
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    guard row >= 0, row < items.count else { return nil }
    let item = items[row]
    let identifier = tableColumn?.identifier

    if identifier == .name {
      let cell = NSTableCellView()
      let imageView = NSImageView(image: item.icon ?? NSImage())
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.imageScaling = .scaleProportionallyDown
      let textField = NSTextField(labelWithString: item.name)
      textField.font = .systemFont(ofSize: 13)
      textField.translatesAutoresizingMaskIntoConstraints = false

      cell.addSubview(imageView)
      cell.addSubview(textField)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
      textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
      let imageWidth = imageView.widthAnchor.constraint(equalToConstant: 16)
      imageWidth.priority = .defaultLow
      let imageHeight = imageView.heightAnchor.constraint(equalToConstant: 16)
      imageHeight.priority = .defaultLow
      let textTrailing = textField.trailingAnchor.constraint(
        lessThanOrEqualTo: cell.trailingAnchor, constant: -8)
      textTrailing.priority = .defaultLow
      NSLayoutConstraint.activate([
        imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
        imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        imageWidth,
        imageHeight,
        textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
        textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        textTrailing,
      ])
      return cell
    }

    let cell = NSTableCellView()
    let text: String
    switch identifier {
    case .kind:
      text = item.kind
    case .size:
      text = item.size
    case .modified:
      text = item.modified
    default:
      text = ""
    }
    let textField = NSTextField(labelWithString: text)
    textField.font = .systemFont(ofSize: 12)
    textField.textColor = .labelColor
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.alignment = identifier == .size ? .right : .left
    textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
    cell.addSubview(textField)
    let textTrailing = textField.trailingAnchor.constraint(
      lessThanOrEqualTo: cell.trailingAnchor, constant: -8)
    textTrailing.priority = .defaultLow

    NSLayoutConstraint.activate([
      textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
      textTrailing,
      textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
    ])
    return cell
  }

  func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting?
  {
    guard row >= 0, row < items.count else { return nil }
    let item = items[row]
    guard !item.isParent else { return nil }
    return item.url as NSURL
  }

  func tableView(
    _ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]
  ) {
    sortItems()
    tableView.reloadData()
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    activatePane()
  }

  private func loadFolderSizesIfNeeded(using generationID: UUID) {
    let currentGeneration = generationID
    for (_, item) in items.enumerated() where item.isDirectory && !item.isParent {
      let folderURL = item.url
      DispatchQueue.global(qos: .utility).async { [weak self] in
        guard let self = self else { return }
        let folderSize = DirectoryItem.folderSizeValue(for: folderURL)
        DispatchQueue.main.async {
          guard self.folderSizeGenerationID == currentGeneration else { return }
          guard let currentIndex = self.items.firstIndex(where: { $0.url == folderURL }) else {
            return
          }
          self.items[currentIndex].sizeValue = folderSize
          self.items[currentIndex].size =
            folderSize.map {
              ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
            } ?? "—"
          if self.tableView.sortDescriptors.contains(where: { $0.key == "sizeValue" }) {
            self.sortItems()
            self.tableView.reloadData()
          } else {
            self.tableView.reloadData(
              forRowIndexes: IndexSet(integer: currentIndex), columnIndexes: IndexSet(integer: 2))
          }
        }
      }
    }
  }
}

private struct DirectoryItem: Comparable {
  let url: URL
  let name: String
  let isDirectory: Bool
  let isParent: Bool
  let isHidden: Bool
  let kind: String
  var size: String
  var sizeValue: Int64?
  let modified: String
  let modifiedDate: Date?
  let icon: NSImage?

  init(url: URL, isParent: Bool = false) {
    self.url = url
    self.isParent = isParent
    self.name = isParent ? ".." : url.lastPathComponent
    if isParent {
      self.isDirectory = true
      self.isHidden = false
      self.kind = "Parent"
      self.size = "—"
      self.modified = "—"
      self.sizeValue = nil
      self.modifiedDate = nil
      self.icon = NSImage(systemSymbolName: "arrow.uturn.left", accessibilityDescription: "Parent")
      return
    }

    let resourceValues = try? url.resourceValues(forKeys: [
      .isDirectoryKey, .contentTypeKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
    ])
    isDirectory = resourceValues?.isDirectory ?? false
    isHidden = resourceValues?.isHidden ?? url.lastPathComponent.hasPrefix(".")
    kind = Self.kindLabel(for: url, resourceValues: resourceValues)

    if let fileSize = resourceValues?.fileSize, !isDirectory {
      sizeValue = Int64(fileSize)
      size = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    } else if isDirectory {
      sizeValue = nil
      size = "Calculating..."
    } else {
      sizeValue = nil
      size = "0 bytes"
    }

    modifiedDate = resourceValues?.contentModificationDate
    if let modifiedDate {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .short
      modified = formatter.string(from: modifiedDate)
    } else {
      modified = "—"
    }

    let icon = NSWorkspace.shared.icon(forFile: url.path)
    icon.size = NSSize(width: 16, height: 16)
    self.icon = icon
  }

  fileprivate static func folderSizeValue(for url: URL) -> Int64? {
    guard
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      )
    else {
      return nil
    }

    var size: Int64 = 0
    for case let fileURL as URL in enumerator {
      let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      if resourceValues?.isRegularFile == true, let fileSize = resourceValues?.fileSize {
        size += Int64(fileSize)
      }
    }
    return size
  }

  private static func kindLabel(for url: URL, resourceValues: URLResourceValues?) -> String {
    if let isDirectory = resourceValues?.isDirectory, isDirectory {
      return "Folder"
    }

    if let contentType = resourceValues?.contentType {
      if let description = contentType.localizedDescription {
        return description
      }
      return contentType.identifier
    }

    return url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased()
  }

  static func == (lhs: DirectoryItem, rhs: DirectoryItem) -> Bool {
    return lhs.url == rhs.url
      && lhs.name == rhs.name
      && lhs.isDirectory == rhs.isDirectory
      && lhs.isParent == rhs.isParent
      && lhs.isHidden == rhs.isHidden
      && lhs.kind == rhs.kind
      && lhs.size == rhs.size
      && lhs.sizeValue == rhs.sizeValue
      && lhs.modified == rhs.modified
      && lhs.modifiedDate == rhs.modifiedDate
  }

  static func parentItem(for url: URL) -> DirectoryItem {
    DirectoryItem(url: url, isParent: true)
  }

  static func < (lhs: DirectoryItem, rhs: DirectoryItem) -> Bool {
    if lhs.isParent != rhs.isParent {
      return lhs.isParent && !rhs.isParent
    }
    if lhs.isDirectory != rhs.isDirectory {
      return lhs.isDirectory && !rhs.isDirectory
    }
    if lhs.isHidden != rhs.isHidden {
      return lhs.isHidden && !rhs.isHidden
    }
    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
  }
}

extension BrowserPaneViewController {
  fileprivate static var defaultDesktopURL: URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let desktop = home.appendingPathComponent("Desktop")
    return FileManager.default.fileExists(atPath: desktop.path) ? desktop : home
  }
}

extension NSUserInterfaceItemIdentifier {
  fileprivate static let name = NSUserInterfaceItemIdentifier("name")
  fileprivate static let kind = NSUserInterfaceItemIdentifier("kind")
  fileprivate static let size = NSUserInterfaceItemIdentifier("size")
  fileprivate static let modified = NSUserInterfaceItemIdentifier("modified")
}
