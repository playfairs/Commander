import Foundation

public struct Volume: Equatable, Sendable {
  public let name: String
  public let url: URL
  public let totalCapacity: Int64?

  public init(name: String, url: URL, totalCapacity: Int64? = nil) {
    self.name = name
    self.url = url
    self.totalCapacity = totalCapacity
  }
}
