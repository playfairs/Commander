import Foundation

public struct Session: Equatable, Sendable {
  public let label: String?
  public let rootURL: URL

  public init(label: String? = nil, rootURL: URL) {
    self.label = label
    self.rootURL = rootURL
  }
}
