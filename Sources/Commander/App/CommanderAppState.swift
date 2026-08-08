import SwiftUI

@MainActor
final class CommanderAppState: ObservableObject {
  static let shared = CommanderAppState()

  private init() {}

  weak var rootViewController: MainViewController?
}
