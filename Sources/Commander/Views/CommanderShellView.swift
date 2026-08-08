import AppKit
import SwiftUI

struct CommanderShellView: View {
  let session: Session
  @State private var isSidebarVisible = true

  var body: some View {
    HStack(spacing: 0) {
      if isSidebarVisible {
        SidebarView()
          .frame(width: 260)
          .background(Color(nsColor: .controlBackgroundColor))

        Divider()
      }

      MainBrowserView(session: session, isSidebarVisible: $isSidebarVisible)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

struct SidebarView: View {
  @StateObject private var store = SidebarSectionStore()

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Locations")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)

        ForEach(store.sections) { section in
          Button(action: { /* future me needs to change this section ok? */  }) {
            HStack(spacing: 8) {
              Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
              Text(section.title)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary)
                .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
          }
          .buttonStyle(.plain)
        }

        HStack {
          Spacer()
          Button(action: {
            _ = store.addSection(rootURL: FileManager.default.homeDirectoryForCurrentUser)
          }) {
            Image(systemName: "plus")
              .font(.system(size: 12, weight: .semibold))
              .frame(width: 26, height: 26)
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .help("Add section")
        }
        .padding(.top, 6)
      }
      .padding(12)

      Divider()
        .padding(.horizontal, 12)

      Text("Favorites")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.top, 10)

      List(favoriteLocations, id: \.title) { location in
        Button(action: { location.action() }) {
          HStack(spacing: 8) {
            Image(systemName: location.iconName)
              .frame(width: 18)
            Text(location.title)
              .font(.system(size: 13))
          }
          .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
      }
      .listStyle(.sidebar)
      .padding(.horizontal, 4)

      Spacer()
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }

  private var favoriteLocations: [FavoriteLocation] {
    [
      FavoriteLocation(title: "Home", iconName: "house.fill") {
        // placeholder action until I get this logic sorted out
      },
      FavoriteLocation(title: "Desktop", iconName: "desktopcomputer") {
        // placeholder action until I get this logic sorted out
      },
      FavoriteLocation(title: "Documents", iconName: "doc.richtext") {
        // placeholder action until I get this logic sorted out
      },
      FavoriteLocation(title: "Downloads", iconName: "arrow.down.circle") {
        // placeholder action until I get this logic sorted out
      },
    ]
  }
}

private struct FavoriteLocation {
  let title: String
  let iconName: String
  let action: () -> Void
}

struct MainBrowserView: View {
  let session: Session
  @Binding var isSidebarVisible: Bool
  @StateObject private var leftModel: BrowserPaneModel
  @StateObject private var rightModel: BrowserPaneModel
  @State private var selectedVolumeURL: URL?
  @State private var searchText = ""

  init(session: Session, isSidebarVisible: Binding<Bool>) {
    self.session = session
    self._isSidebarVisible = isSidebarVisible
    _leftModel = StateObject(wrappedValue: BrowserPaneModel(rootURL: session.rootURL))
    let rightURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    _rightModel = StateObject(wrappedValue: BrowserPaneModel(rootURL: rightURL))
    _selectedVolumeURL = State(initialValue: session.rootURL)
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
        BrowserPaneView(title: "Left Pane", model: leftModel)
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
          .background(Color(nsColor: .textBackgroundColor))
          .cornerRadius(8)

        BrowserPaneView(title: "Right Pane", model: rightModel)
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
          .background(Color(nsColor: .textBackgroundColor))
          .cornerRadius(8)
      }
      .padding(12)

      Divider()

      bottomStatusBar
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var header: some View {
    HStack(spacing: 12) {
      HStack(spacing: 8) {
        Image(
          systemName: selectedVolumeURL == nil
            ? "externaldrive" : volumeIconName(for: selectedVolumeURL!)
        )
        .foregroundColor(.accentColor)

        VStack(alignment: .leading, spacing: 2) {
          Text("Commander")
            .font(.system(size: 15, weight: .bold))
          Text(selectedVolumeURL?.lastPathComponent ?? session.rootURL.lastPathComponent)
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
                selectedVolumeURL = volume
                await leftModel.loadDirectory(volume, replaceHistory: true)
                await rightModel.loadDirectory(volume, replaceHistory: true)
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
                selectedVolumeURL == volume
                  ? Color(nsColor: .selectedControlColor) : Color(nsColor: .controlBackgroundColor)
              )
              .foregroundColor(selectedVolumeURL == volume ? .white : .primary)
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
        Button(action: model.goBack) { Image(systemName: "chevron.left") }
          .buttonStyle(.plain)
          .disabled(!model.canGoBack)

        Button(action: model.goForward) { Image(systemName: "chevron.right") }
          .buttonStyle(.plain)
          .disabled(!model.canGoForward)

        Button(action: model.goUp) { Image(systemName: "arrow.up") }
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
            model.selectedItemId = nil
          }

        Table(model.items, selection: $model.selectedItemId) {
          TableColumn("Name") { item in
            HStack(spacing: 8) {
              if let icon = item.icon {
                Image(nsImage: icon)
                  .resizable()
                  .frame(width: 14, height: 14)
              }
              Text(item.name)
                .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
              model.selectedItemId = item.id
            }
            .onTapGesture(count: 2) {
              model.selectedItemId = item.id
              model.activateSelectedItem()
            }
            .contextMenu {
              Button("Open") {
                model.selectedItemId = item.id
                model.activateSelectedItem()
              }
              Button("Refresh") {
                Task { await model.reloadCurrentDirectory() }
              }
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
        .tableStyle(.inset)
      }
      .onChange(of: model.selectedItemId) { _, _ in
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
    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
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
    "\(items.count) items — \(currentURL.lastPathComponent.isEmpty ? currentURL.path : currentURL.lastPathComponent)"
  }

  init(rootURL: URL) {
    currentURL = rootURL
    Task { await loadDirectory(rootURL, replaceHistory: true) }
  }

  func loadDirectory(_ url: URL, replaceHistory: Bool) async {
    guard await isDirectory(url) else { return }
    currentURL = url
    let resourceKeys: Set<URLResourceKey> = [
      .isDirectoryKey, .contentTypeKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
    ]
    let options: FileManager.DirectoryEnumerationOptions =
      showHiddenFiles ? [] : [.skipsHiddenFiles]
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
