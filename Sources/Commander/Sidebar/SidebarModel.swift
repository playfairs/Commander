import Foundation
import SwiftUI

@MainActor
final class SidebarSectionStore: ObservableObject {
  @Published private(set) var sections: [SidebarSection] = []

  init() {
    addSection(rootURL: FileManager.default.homeDirectoryForCurrentUser)
  }

  @discardableResult
  func addSection(rootURL: URL, title: String? = nil) -> SidebarSection {
    let sectionTitle = title ?? "Section \(sections.count + 1)"
    let section = SidebarSection(id: UUID(), title: sectionTitle, rootURL: rootURL)
    sections.append(section)
    return section
  }
}

@MainActor
struct SidebarSection: Identifiable, Equatable {
  let id: UUID
  let title: String
  let rootURL: URL
}
