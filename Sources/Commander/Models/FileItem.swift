import Foundation

public enum FileItemKind: String, CaseIterable, Sendable {
  case file
  case directory
  case volume
  case package
  case unknown
}

public struct FileItem: Equatable, Sendable {
  public let name: String
  public let path: String
  public let kind: FileItemKind
  public let isDirectory: Bool
  public let size: Int64

  public init(name: String, path: String, kind: FileItemKind, isDirectory: Bool, size: Int64) {
    self.name = name
    self.path = path
    self.kind = kind
    self.isDirectory = isDirectory
    self.size = size
  }

  public var displayName: String {
    name
  }
}
