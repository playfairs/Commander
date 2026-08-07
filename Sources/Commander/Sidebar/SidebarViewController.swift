import AppKit

@MainActor
final class SidebarViewController: NSViewController {
  private let sectionStore: SidebarSectionStore
  private let scrollView = NSScrollView()
  private let contentView = NSStackView()

  init(sectionStore: SidebarSectionStore) {
    self.sectionStore = sectionStore
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

    contentView.orientation = .vertical
    contentView.alignment = .leading
    contentView.spacing = 6
    contentView.translatesAutoresizingMaskIntoConstraints = false

    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.documentView = contentView
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    let headerLabel = NSTextField(labelWithString: "Sections")
    headerLabel.font = .systemFont(ofSize: 12, weight: .medium)
    headerLabel.textColor = .secondaryLabelColor
    headerLabel.translatesAutoresizingMaskIntoConstraints = false

    let header = NSStackView(views: [headerLabel])
    header.orientation = .horizontal
    header.alignment = .centerY
    header.spacing = 8
    header.translatesAutoresizingMaskIntoConstraints = false

    let container = NSStackView(views: [header, scrollView])
    container.orientation = .vertical
    container.spacing = 8
    container.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(container)

    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
      container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
      container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
      container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
      contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
      contentView.heightAnchor.constraint(
        greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
    ])

    self.view = view
    reloadSections()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    reloadSections()
  }

  func addSection() {
    let section = sectionStore.addSection(rootURL: FileManager.default.homeDirectoryForCurrentUser)
    reloadSections()
    NSLog("Added sidebar section: \(section.title)")
  }

  private func reloadSections() {
    contentView.arrangedSubviews.forEach { $0.removeFromSuperview() }

    for section in sectionStore.sections {
      let label = NSTextField(labelWithString: section.title)
      label.font = .systemFont(ofSize: 12, weight: .medium)
      label.textColor = .secondaryLabelColor
      contentView.addArrangedSubview(label)
    }
  }
}
