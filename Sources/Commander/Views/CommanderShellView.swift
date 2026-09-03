import AppKit
import Quartz
import SwiftUI

struct CommanderShellView: View {
  let session: Session
  @AppStorage("CommanderSidebarVisible") private var isSidebarVisible = true
  @StateObject private var selectionStore = SelectionsStore()
  @State private var openSelectionURL: URL?

  var body: some View {
    HStack(spacing: 0) {
      if isSidebarVisible {
        SidebarView(selectionStore: selectionStore) { url in
          openSelectionURL = url
        }
        .frame(width: 260)
        .background(Color(nsColor: .controlBackgroundColor))
        .transition(.move(edge: .leading).combined(with: .opacity))

        Divider()
      }

      MainBrowserView(
        session: session,
        isSidebarVisible: $isSidebarVisible,
        selectionStore: selectionStore,
        openSelectionURL: $openSelectionURL)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

struct MainBrowserView: View {
  let session: Session
  @Binding var isSidebarVisible: Bool
  @StateObject private var leftModel: BrowserPaneModel
  @StateObject private var rightModel: BrowserPaneModel
  @State private var activePane: ActivePane = .left
  @ObservedObject var selectionStore: SelectionsStore
  @Binding var openSelectionURL: URL?
  @State private var searchText = ""

  init(
    session: Session,
    isSidebarVisible: Binding<Bool>,
    selectionStore: SelectionsStore,
    openSelectionURL: Binding<URL?>
  ) {
    self.session = session
    self._isSidebarVisible = isSidebarVisible
    _leftModel = StateObject(wrappedValue: BrowserPaneModel(rootURL: session.rootURL))
    let rightURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    _rightModel = StateObject(wrappedValue: BrowserPaneModel(rootURL: rightURL))
    self._selectionStore = ObservedObject(wrappedValue: selectionStore)
    self._openSelectionURL = openSelectionURL
  }

  private enum ActivePane {
    case left
    case right
  }

  private var activeModel: BrowserPaneModel {
    activePane == .left ? leftModel : rightModel
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      volumeBar
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .windowBackgroundColor))

      Divider()

      HStack(spacing: 12) {
        BrowserPaneView(
          title: "Left Pane", model: leftModel, selectionStore: selectionStore,
          isActive: activePane == .left, onActivate: { activePane = .left }
        )
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)

        BrowserPaneView(
          title: "Right Pane", model: rightModel, selectionStore: selectionStore,
          isActive: activePane == .right, onActivate: { activePane = .right }
        )
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
      }
      .padding(12)

      Divider()

      bottomStatusBar
    }
    .onChange(of: openSelectionURL) { oldURL, newURL in
      guard let url = newURL else { return }
      Task {
        await activeModel.loadDirectory(url, replaceHistory: true)
        openSelectionURL = nil
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var header: some View {
    HStack(spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: volumeIconName(for: activeModel.currentURL))
          .foregroundColor(.accentColor)

        VStack(alignment: .leading, spacing: 2) {
          Text("Commander")
            .font(.system(size: 15, weight: .bold))
          Text(
            activeModel.currentURL.lastPathComponent.isEmpty
              ? activeModel.currentURL.path : activeModel.currentURL.lastPathComponent
          )
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(1)
        }
      }

      Spacer()

      Button(action: { withAnimation { isSidebarVisible.toggle() } }) {
        Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.right")
      }
      .buttonStyle(.bordered)
      .controlSize(.small)

      SearchField(text: $searchText)
        .frame(maxWidth: 240)

      HStack(spacing: 8) {
        Button(action: { leftModel.showHiddenFiles.toggle() }) {
          Label("Hidden", systemImage: leftModel.showHiddenFiles ? "eye.fill" : "eye")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button {
          Task {
            await leftModel.reloadCurrentDirectory()
            await rightModel.reloadCurrentDirectory()
          }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(12)
  }

  private var volumeBar: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Mounted Volumes")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(volumeURLs, id: \.path) { volume in
            Button {
              Task {
                await activeModel.loadDirectory(volume, replaceHistory: true)
              }
            } label: {
              HStack(spacing: 6) {
                Image(systemName: volumeIconName(for: volume))
                Text(volume.lastPathComponent.isEmpty ? volume.path : volume.lastPathComponent)
              }
              .font(.system(size: 12, weight: .regular))
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(
                activeModel.currentURL == volume
                  ? Color(nsColor: .selectedControlColor) : Color(nsColor: .controlBackgroundColor)
              )
              .foregroundColor(activeModel.currentURL == volume ? .white : .primary)
              .cornerRadius(8)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 12)
      }
    }
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var bottomStatusBar: some View {
    HStack(spacing: 20) {
      statusBadge("View", key: "F3")
      statusBadge("Edit", key: "F4")
      statusBadge("Copy", key: "F5")
      statusBadge("Move", key: "F6")
      statusBadge("New Folder", key: "F7")
      statusBadge("Delete", key: "F8")
      Spacer()
      Text("")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .background(Color(nsColor: .controlBackgroundColor))
  }

  private func statusBadge(_ label: String, key: String) -> some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.system(size: 11, weight: .semibold))
      Text(key)
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(4)
    }
    .foregroundColor(.primary)
    .padding(.vertical, 2)
    .padding(.horizontal, 4)
    .background(Color(nsColor: .controlBackgroundColor))
    .cornerRadius(6)
  }

  private var volumeURLs: [URL] {
    (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? [])
      .filter { $0.path.hasPrefix("/Volumes") }
      .sorted {
        $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent)
          == .orderedAscending
      }
  }

  private func volumeIconName(for volume: URL) -> String {
    if volume.path.contains("Macintosh") || volume.path.contains("macOS") {
      return "internaldrive"
    }
    return "externaldrive"
  }
}

struct SearchField: View {
  @Binding var text: String

  var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField("Search…", text: $text)
        .textFieldStyle(.plain)
    }
    .padding(8)
    .background(Color(nsColor: .textBackgroundColor))
    .cornerRadius(8)
  }
}

struct BrowserPaneView: View {
  let title: String
  @ObservedObject var model: BrowserPaneModel
  @ObservedObject var selectionStore: SelectionsStore
  let isActive: Bool
  let onActivate: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
        Spacer()
        Text(model.currentURL.path)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .padding(10)
      .background(Color(nsColor: .controlBackgroundColor))

      HStack(spacing: 10) {
        Button(action: {
          onActivate()
          model.goBack()
        }) { Image(systemName: "chevron.left") }
        .buttonStyle(.plain)
        .disabled(!model.canGoBack)

        Button(action: {
          onActivate()
          model.goForward()
        }) { Image(systemName: "chevron.right") }
        .buttonStyle(.plain)
        .disabled(!model.canGoForward)

        Button(action: {
          onActivate()
          model.goUp()
        }) { Image(systemName: "arrow.up") }
        .buttonStyle(.plain)
        .disabled(!model.canGoUp)

        Spacer()

        Toggle("Hidden", isOn: $model.showHiddenFiles)
          .toggleStyle(.switch)
          .labelsHidden()
      }
      .padding(10)
      .background(Color(nsColor: .windowBackgroundColor))

      Divider()

      ZStack(alignment: .topLeading) {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {
            onActivate()
            model.selectedItemId = nil
          }

        Table(model.items, selection: $model.selectedItemId) {
          TableColumn("Name") { item in
            HStack(spacing: 8) {
              if let icon = item.icon {
                Image(nsImage: icon)
                  .resizable()
                  .frame(width: 14, height: 14)
              } else {
                BrowserFileIcon(url: item.url)
              }
              Text(item.name)
                .lineLimit(1)
              Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .simultaneousGesture(
              TapGesture().onEnded {
                onActivate()
                model.selectedItemId = item.id
              }
            )
            .simultaneousGesture(
              TapGesture(count: 2).onEnded {
                onActivate()
                model.selectedItemId = item.id
                model.activateSelectedItem()
              }
            )
            .contextMenu {
              Button("Open") {
                onActivate()
                model.selectedItemId = item.id
                model.activateSelectedItem()
              }
              Button("Quick Look") {
                onActivate()
                model.selectedItemId = item.id
                model.quickLookSelectedItem()
              }
              Button("Rename") {
                onActivate()
                model.selectedItemId = item.id
                model.renameSelectedItem()
              }
              Button("Show in Finder") {
                onActivate()
                model.selectedItemId = item.id
                model.revealSelectedItemInFinder()
              }
              Button("Move to Trash") {
                onActivate()
                model.selectedItemId = item.id
                model.moveSelectedItemToTrash()
              }
              Button("Delete Immediately") {
                onActivate()
                model.selectedItemId = item.id
                model.deleteSelectedItemImmediately()
              }
              Button("Get Info") {
                onActivate()
                model.selectedItemId = item.id
                model.openInfoForSelectedItem()
              }
              if item.isDirectory && item.name != ".." {
                Button("Favorite") {
                  onActivate()
                  model.selectedItemId = item.id
                  selectionStore.addSelection(item.url)
                }
              }
            }
          }
          .width(min: 250, ideal: 320)

          TableColumn("Kind") { item in
            Text(item.kind)
              .frame(maxWidth: .infinity, alignment: .leading)
              .foregroundStyle(.secondary)
              .contentShape(Rectangle())
              .simultaneousGesture(
                TapGesture().onEnded {
                  onActivate()
                  model.selectedItemId = item.id
                }
              )
              .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                  onActivate()
                  model.selectedItemId = item.id
                  model.activateSelectedItem()
                }
              )
          }
          .width(min: 100, ideal: 150)

          TableColumn("Size") { item in
            Text(item.size)
              .frame(maxWidth: .infinity, alignment: .leading)
              .foregroundStyle(.secondary)
              .contentShape(Rectangle())
              .simultaneousGesture(
                TapGesture().onEnded {
                  onActivate()
                  model.selectedItemId = item.id
                }
              )
              .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                  onActivate()
                  model.selectedItemId = item.id
                  model.activateSelectedItem()
                }
              )
          }
          .width(min: 100, ideal: 120)

          TableColumn("Modified") { item in
            Text(item.modified)
              .frame(maxWidth: .infinity, alignment: .leading)
              .foregroundStyle(.secondary)
              .contentShape(Rectangle())
              .simultaneousGesture(
                TapGesture().onEnded {
                  onActivate()
                  model.selectedItemId = item.id
                }
              )
              .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                  onActivate()
                  model.selectedItemId = item.id
                  model.activateSelectedItem()
                }
              )
          }
          .width(min: 140, ideal: 160)
        }
        .tableStyle(.inset)
      }
      .onChange(of: model.selectedItemId) { _, _ in
        onActivate()
        model.onSelectionChanged()
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
    .background(Color(nsColor: .windowBackgroundColor))
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 2)
    )
    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    .contentShape(Rectangle())
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
  private var loadTask: Task<Void, Never>?
  private var loadGeneration = UUID()

  var canGoBack: Bool { historyIndex > 0 }
  var canGoForward: Bool { historyIndex + 1 < history.count }
  var canGoUp: Bool { parentURL(for: currentURL) != nil }

  var statusText: String {
    "\(items.count) items — \(currentURL.lastPathComponent.isEmpty ? currentURL.path : currentURL.lastPathComponent)"
  }

  init(rootURL: URL) {
    currentURL = rootURL
    Task { await loadDirectory(rootURL, replaceHistory: true) }
  }

  func loadDirectory(_ url: URL, replaceHistory: Bool) async {
    loadTask?.cancel()
    let generation = UUID()
    loadGeneration = generation
    let includeHiddenFiles = showHiddenFiles

    let task = Task { [weak self] in
      do {
        let snapshots = try await Task.detached(priority: .userInitiated) {
          try BrowserFileSnapshot.load(from: url, showHiddenFiles: includeHiddenFiles)
        }.value
        guard !Task.isCancelled, let self, self.loadGeneration == generation else { return }

        var loadedItems = snapshots.map(BrowserFileItem.init(snapshot:)).sorted()
        if let parent = self.parentURL(for: url) {
          loadedItems.insert(BrowserFileItem.parentItem(parent), at: 0)
        }
        self.items = loadedItems
        self.currentURL = url
        if replaceHistory {
          self.history = [url]
          self.historyIndex = 0
        } else {
          self.history = Array(self.history.prefix(self.historyIndex + 1)) + [url]
          self.historyIndex += 1
        }
      } catch is CancellationError {
        return
      } catch {
        guard let self, self.loadGeneration == generation else { return }
        self.items = []
      }
    }
    loadTask = task
  }

  func onSelectionChanged() {}

  func reloadCurrentDirectory() async {
    await loadDirectory(currentURL, replaceHistory: true)
  }

  func activateSelectedItem() {
    guard let id = selectedItemId,
      let selected = items.first(where: { $0.id == id })
    else { return }
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

  func quickLookSelectedItem() {
    guard let id = selectedItemId,
      let selected = items.first(where: { $0.id == id }),
      !selected.isDirectory || selected.name != ".."
    else { return }
    NSWorkspace.shared.open(selected.url)
  }

  func renameSelectedItem() {
    guard let id = selectedItemId,
      let selected = items.first(where: { $0.id == id }),
      selected.name != ".."
    else { return }
    renameItem(selected)
  }

  func revealSelectedItemInFinder() {
    guard let id = selectedItemId,
      let selected = items.first(where: { $0.id == id }),
      !selected.name.starts(with: "..")
    else { return }
    NSWorkspace.shared.activateFileViewerSelecting([selected.url])
  }

  func moveSelectedItemToTrash() {
    guard let id = selectedItemId,
      let selected = items.first(where: { $0.id == id }),
      selected.name != ".."
    else { return }
    do {
      try FileManager.default.trashItem(at: selected.url, resultingItemURL: nil)
      Task { await reloadCurrentDirectory() }
    } catch {
      // overly simplified model, will work on expanding this shit when I feel like it ok?
    }
  }

  func deleteSelectedItemImmediately() {
    guard let id = selectedItemId,
      let selected = items.first(where: { $0.id == id }),
      selected.name != ".."
    else { return }
    do {
      try FileManager.default.removeItem(at: selected.url)
      Task { await reloadCurrentDirectory() }
    } catch {
      // overly simplified model, will work on expanding this shit when I feel like it ok?
    }
  }

  func openInfoForSelectedItem() {
    guard let id = selectedItemId,
      let selected = items.first(where: { $0.id == id }),
      !selected.name.starts(with: "..")
    else { return }
    NSWorkspace.shared.activateFileViewerSelecting([selected.url])
  }

  private func parentURL(for url: URL) -> URL? {
    let parent = url.deletingLastPathComponent()
    guard parent.path != url.path else { return nil }
    return parent
  }

  private func renameItem(_ item: BrowserFileItem) {
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
        Task { await reloadCurrentDirectory() }
      } catch {
        // overly simplified model, will work on expanding this shit when I feel like it ok?
      }
    }
  }

}

private struct BrowserFileSnapshot: Sendable {
  let url: URL
  let name: String
  let isDirectory: Bool
  let kind: String
  let size: String
  let modified: String

  static func load(from url: URL, showHiddenFiles: Bool) throws -> [BrowserFileSnapshot] {
    let resourceKeys: Set<URLResourceKey> = [
      .isDirectoryKey, .contentTypeKey, .fileSizeKey, .contentModificationDateKey,
    ]
    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
    guard resourceValues.isDirectory == true else { return [] }

    let options: FileManager.DirectoryEnumerationOptions =
      showHiddenFiles ? [] : [.skipsHiddenFiles]
    let urls = try FileManager.default.contentsOfDirectory(
      at: url, includingPropertiesForKeys: Array(resourceKeys), options: options)
    return
      try urls
      .filter { showHiddenFiles || !$0.lastPathComponent.hasPrefix(".") }
      .map { try BrowserFileSnapshot(url: $0, resourceKeys: resourceKeys) }
  }

  init(url: URL, resourceKeys: Set<URLResourceKey>) throws {
    self.url = url
    name = url.lastPathComponent
    let resourceValues = try url.resourceValues(forKeys: resourceKeys)
    isDirectory = resourceValues.isDirectory ?? false
    if let contentType = resourceValues.contentType {
      kind = isDirectory ? "Folder" : (contentType.localizedDescription ?? contentType.identifier)
    } else {
      kind =
        isDirectory
        ? "Folder" : (url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased())
    }
    if let fileSize = resourceValues.fileSize, !isDirectory {
      size = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    } else {
      size = isDirectory ? "—" : "0 bytes"
    }
    modified =
      resourceValues.contentModificationDate?.formatted(
        date: .abbreviated, time: .shortened) ?? "—"
  }
}

@MainActor
private struct BrowserFileIcon: View {
  private static let cache = NSCache<NSURL, NSImage>()
  let url: URL
  @State private var icon: NSImage?

  var body: some View {
    Group {
      if let icon {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 14, height: 14)
      } else {
        Color.clear.frame(width: 14, height: 14)
      }
    }
    .task(id: url) {
      let cacheKey = url as NSURL
      if let cached = Self.cache.object(forKey: cacheKey) {
        icon = cached
        return
      }
      let loaded = NSWorkspace.shared.icon(forFile: url.path)
      loaded.size = NSSize(width: 16, height: 16)
      Self.cache.setObject(loaded, forKey: cacheKey)
      icon = loaded
    }
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

  fileprivate init(snapshot: BrowserFileSnapshot) {
    url = snapshot.url
    name = snapshot.name
    isDirectory = snapshot.isDirectory
    kind = snapshot.kind
    size = snapshot.size
    modified = snapshot.modified
    icon = nil
  }

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
    BrowserFileItem(
      url: url,
      name: "..",
      isDirectory: true,
      kind: "Parent",
      size: "—",
      modified: "—",
      icon: NSImage(systemSymbolName: "arrow.uturn.left", accessibilityDescription: nil)
    )
  }

  private init(
    url: URL, name: String, isDirectory: Bool, kind: String, size: String, modified: String,
    icon: NSImage?
  ) {
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
