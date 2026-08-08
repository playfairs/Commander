import SwiftUI
import AppKit

struct CommanderShellView: View {
  let session: Session

  var body: some View {
    HStack(spacing: 0) {
      SidebarView()
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
      Divider()
      BrowserPaneView(session: session)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

struct SidebarView: View {
  @StateObject private var store = SidebarSectionStore()

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Sections")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.top, 16)
        .padding(.horizontal, 12)

      List(store.sections) { section in
        Text(section.title)
          .padding(.vertical, 6)
      }
      .listStyle(.sidebar)
      .padding(.horizontal, 8)

      Spacer()
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }
}

struct BrowserPaneView: View {
  @StateObject private var model: BrowserPaneModel

  init(session: Session) {
    _model = StateObject(wrappedValue: BrowserPaneModel(rootURL: session.rootURL))
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Button(action: model.goBack) {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(.plain)
        .disabled(!model.canGoBack)

        Button(action: model.goForward) {
          Image(systemName: "chevron.right")
        }
        .buttonStyle(.plain)
        .disabled(!model.canGoForward)

        Button(action: model.goUp) {
          Image(systemName: "arrow.up")
        }
        .buttonStyle(.plain)
        .disabled(!model.canGoUp)

        Text(model.currentURL.path)
          .font(.system(size: 12, weight: .medium))
          .lineLimit(1)
          .truncationMode(.middle)

        Spacer()

        Toggle(isOn: $model.showHiddenFiles) {
          Text("Show hidden")
            .font(.system(size: 12))
        }
        .toggleStyle(.switch)
        .labelsHidden()
      }
      .padding(10)
      .background(Color(nsColor: .windowBackgroundColor))

      Divider()

      Table(model.items, selection: $model.selectedItemId) {
        TableColumn("Name") { item in
          HStack(spacing: 6) {
            if let icon = item.icon {
              Image(nsImage: icon)
                .resizable()
                .frame(width: 14, height: 14)
            }
            Text(item.name)
              .lineLimit(1)
          }
        }
        .width(min: 250, ideal: 320)

        TableColumn("Kind") { item in
          Text(item.kind)
            .foregroundStyle(.secondary)
        }
        .width(min: 100, ideal: 150)

        TableColumn("Size") { item in
          Text(item.size)
            .foregroundStyle(.secondary)
        }
        .width(min: 100, ideal: 120)

        TableColumn("Modified") { item in
          Text(item.modified)
            .foregroundStyle(.secondary)
        }
        .width(min: 140, ideal: 160)
      }
      .onChange(of: model.selectedItemId) { _ in
        model.onSelectionChanged()
      }
      .onTapGesture(count: 2) {
        model.activateSelectedItem()
      }
      .padding(.horizontal, 8)

      Divider()

      HStack {
        Text(model.statusText)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(10)
      .background(Color(nsColor: .windowBackgroundColor))
    }
    .task {
      await model.loadDirectory(model.currentURL, replaceHistory: true)
    }
  }
}

@MainActor
final class BrowserPaneModel: ObservableObject {
  @Published var items: [BrowserFileItem] = []
  @Published var currentURL: URL
  @Published var showHiddenFiles = false {
    didSet { Task { await loadDirectory(currentURL, replaceHistory: true) } }
  }
  @Published var selectedItemId: UUID?

  private var history: [URL] = []
  private var historyIndex = 0

  var canGoBack: Bool { historyIndex > 0 }
  var canGoForward: Bool { historyIndex + 1 < history.count }
  var canGoUp: Bool { parentURL(for: currentURL) != nil }

  var statusText: String {
    "\(items.count) items — \(currentURL.path)"
  }

  init(rootURL: URL) {
    currentURL = rootURL
  }

  func loadDirectory(_ url: URL, replaceHistory: Bool) async {
    guard await isDirectory(url) else { return }
    currentURL = url
    let resourceKeys: Set<URLResourceKey> = [
      .isDirectoryKey, .contentTypeKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
    ]
    let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]
    do {
      let urls = try FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: Array(resourceKeys),
        options: options)
      let filtered = urls.filter { showHiddenFiles || !$0.lastPathComponent.hasPrefix(".") }
      let loadedItems = try filtered.map { url in
        try BrowserFileItem(url: url, resourceKeys: resourceKeys)
      }
      items = loadedItems.sorted()
      if let parent = parentURL(for: url) {
        items.insert(BrowserFileItem.parentItem(parent), at: 0)
      }
      if replaceHistory {
        history = [url]
        historyIndex = 0
      } else {
        history = Array(history.prefix(historyIndex + 1)) + [url]
        historyIndex += 1
      }
    } catch {
      items = []
    }
  }

  func onSelectionChanged() {
  }

  func activateSelectedItem() {
    guard let id = selectedItemId,
          let selected = items.first(where: { $0.id == id }) else { return }
    if selected.isDirectory {
      Task { await loadDirectory(selected.url, replaceHistory: false) }
    }
  }

  func goBack() {
    guard canGoBack else { return }
    historyIndex -= 1
    Task { await loadDirectory(history[historyIndex], replaceHistory: false) }
  }

  func goForward() {
    guard canGoForward else { return }
    historyIndex += 1
    Task { await loadDirectory(history[historyIndex], replaceHistory: false) }
  }

  func goUp() {
    guard let parent = parentURL(for: currentURL) else { return }
    Task { await loadDirectory(parent, replaceHistory: false) }
  }

  private func parentURL(for url: URL) -> URL? {
    let parent = url.deletingLastPathComponent()
    guard parent.path != url.path else { return nil }
    return parent
  }

  private func isDirectory(_ url: URL) async -> Bool {
    let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
    return resourceValues?.isDirectory == true
  }
}

struct BrowserFileItem: Identifiable, Comparable {
  let id = UUID()
  let url: URL
  let name: String
  let isDirectory: Bool
  let kind: String
  let size: String
  let modified: String
  let icon: NSImage?

  init(url: URL, resourceKeys: Set<URLResourceKey>) throws {
    self.url = url
    let resourceValues = try url.resourceValues(forKeys: resourceKeys)
    name = url.lastPathComponent
    isDirectory = resourceValues.isDirectory ?? false
    kind = Self.kindLabel(for: url, resourceValues: resourceValues)
    if let fileSize = resourceValues.fileSize, !isDirectory {
      size = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    } else if isDirectory {
      size = "—"
    } else {
      size = "0 bytes"
    }
    if let modifiedDate = resourceValues.contentModificationDate {
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

  static func parentItem(_ url: URL) -> BrowserFileItem {
    let item = BrowserFileItem(
      url: url,
      name: "..",
      isDirectory: true,
      kind: "Parent",
      size: "—",
      modified: "—",
      icon: NSImage(systemSymbolName: "arrow.uturn.left", accessibilityDescription: "Parent")
    )
    return item
  }

  private init(url: URL, name: String, isDirectory: Bool, kind: String, size: String, modified: String, icon: NSImage?) {
    self.url = url
    self.name = name
    self.isDirectory = isDirectory
    self.kind = kind
    self.size = size
    self.modified = modified
    self.icon = icon
  }

  private static func kindLabel(for url: URL, resourceValues: URLResourceValues?) -> String {
    if let isDirectory = resourceValues?.isDirectory, isDirectory {
      return "Folder"
    }
    if let contentType = resourceValues?.contentType {
      return contentType.localizedDescription ?? contentType.identifier
    }
    return url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased()
  }

  static func < (lhs: BrowserFileItem, rhs: BrowserFileItem) -> Bool {
    if lhs.name == ".." { return true }
    if rhs.name == ".." { return false }
    if lhs.isDirectory != rhs.isDirectory {
      return lhs.isDirectory && !rhs.isDirectory
    }
    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
  }
}
