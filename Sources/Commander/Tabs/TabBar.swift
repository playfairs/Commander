import AppKit

final class TabBar: NSView {
  private let stackView = NSStackView()
  private let tabsContainer = NSStackView()
  private let addButton = NSButton()

  var tabs: [Tab] = [] {
    didSet { updateTabs() }
  }

  var selectedIndex: Int = 0 {
    didSet { updateSelection() }
  }

  var onSelectTab: ((Int) -> Void)?
  var onAddTab: (() -> Void)?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    translatesAutoresizingMaskIntoConstraints = false
    wantsLayer = true
    layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    setupViews()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: NSView.noIntrinsicMetric, height: 40)
  }

  private func setupViews() {
    stackView.orientation = .horizontal
    stackView.alignment = .centerY
    stackView.distribution = .fill
    stackView.spacing = 6
    stackView.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
    stackView.translatesAutoresizingMaskIntoConstraints = false

    tabsContainer.orientation = .horizontal
    tabsContainer.alignment = .centerY
    tabsContainer.spacing = 6
    tabsContainer.translatesAutoresizingMaskIntoConstraints = false

    addButton.title = "+"
    addButton.bezelStyle = .texturedRounded
    addButton.controlSize = .small
    addButton.target = self
    addButton.action = #selector(addTabAction)
    addButton.translatesAutoresizingMaskIntoConstraints = false

    stackView.addArrangedSubview(tabsContainer)
    stackView.addArrangedSubview(addButton)

    addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private func updateTabs() {
    tabsContainer.arrangedSubviews.forEach {
      tabsContainer.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }

    for (index, tab) in tabs.enumerated() {
      let button = NSButton(title: tab.title, target: self, action: #selector(tabButtonAction(_:)))
      button.tag = index
      button.bezelStyle = .texturedRounded
      button.controlSize = .small
      button.setButtonType(.momentaryPushIn)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.toolTip = tab.title
      tabsContainer.addArrangedSubview(button)
    }
    updateSelection()
  }

  private func updateSelection() {
    for case let button as NSButton in tabsContainer.arrangedSubviews {
      button.state = button.tag == selectedIndex ? .on : .off
    }
  }

  @objc private func tabButtonAction(_ sender: NSButton) {
    onSelectTab?(sender.tag)
  }

  @objc private func addTabAction() {
    onAddTab?()
  }
}
