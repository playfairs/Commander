import Foundation

@MainActor
final class SidebarViewController: NSObject {
  private let sectionStore: SidebarSectionStore

  init(sectionStore: SidebarSectionStore) {
    self.sectionStore = sectionStore
    super.init()
  }

  func addSection() {
    let section = sectionStore.addSection(rootURL: FileManager.default.homeDirectoryForCurrentUser)
    NSLog("Added sidebar section: \(section.title)")
  }
}
