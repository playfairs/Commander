import Foundation
import SwiftUI

@MainActor
final class SelectionsStore: ObservableObject {
  @Published private(set) var selections: [String] = []

  private let fileURL: URL

  init() {
    let bundleID = Bundle.main.bundleIdentifier ?? "Commander"
    let supportURLs = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)
    let supportURL =
      supportURLs.first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
        "Library/Application Support")
    let appFolder = supportURL.appendingPathComponent(bundleID, isDirectory: true)

    do {
      try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
    } catch {
      assertionFailure("Unable to create App Support folder: \(error)")
    }

    fileURL = appFolder.appendingPathComponent("selections.json")
    loadSelections()
  }

  func addSelection(_ url: URL) {
    let path = url.path
    guard !selections.contains(path) else { return }
    selections.append(path)
    saveSelections()
  }

  func removeSelection(_ url: URL) {
    let path = url.path
    selections.removeAll { $0 == path }
    saveSelections()
  }

  private func loadSelections() {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

    do {
      let data = try Data(contentsOf: fileURL)
      let decoded = try JSONDecoder().decode([String].self, from: data)
      selections = decoded
    } catch {
      selections = []
    }
  }

  private func saveSelections() {
    do {
      let data = try JSONEncoder().encode(selections)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      assertionFailure("Unable to save selections: \(error)")
    }
  }
}
