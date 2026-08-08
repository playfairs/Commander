import AppKit
import Quartz
import UniformTypeIdentifiers

private func isDirectory(_ url: URL) -> Bool {
  var isDirectory: ObjCBool = false
  return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    && isDirectory.boolValue
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

  func handleToolbarAction(_ identifier: String) {
    switch identifier {
    case "back":
      activePane?.goBack()
    case "forward":
      activePane?.goForward()
    case "reveal":
      activePane?.revealInFinder()
    case "viewList":
      activePane?.setListViewMode()
    case "viewGrid":
      activePane?.setIconViewMode()
    case "info":
      activePane?.showSelectedInfo()
    default:
      break
    }
    updateStatusBar()
  }

  @objc func handleToolbarItem(_ sender: NSToolbarItem) {
    handleToolbarAction(sender.itemIdentifier.rawValue)
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
  func browserPaneDidActivate(_ pane: BrowserPaneViewController) {
    activePane = pane
    updateStatusBar()
  }

  func browserPane(_ pane: BrowserPaneViewController, didUpdateStatus status: String) {
    if activePane === pane {
      updateStatusBar()
    }
  }
}
