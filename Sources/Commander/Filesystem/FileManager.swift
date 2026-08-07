import Foundation

public enum FileSystemOperations {
  public static func duplicateItem(at sourceURL: URL, in destinationDirectory: URL) throws -> URL {
    let destinationName = uniqueName(
      for: sourceURL.lastPathComponent, in: destinationDirectory, style: .copy)
    let destinationURL = destinationDirectory.appendingPathComponent(destinationName)
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    return destinationURL
  }

  public static func createFolder(named name: String, in directory: URL) throws -> URL {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let baseName = trimmedName.isEmpty ? "New Folder" : trimmedName
    let destinationName = uniqueName(for: baseName, in: directory, style: .folder)
    let destinationURL = directory.appendingPathComponent(destinationName)
    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false)
    return destinationURL
  }

  private enum NameStyle {
    case copy
    case folder
  }

  private static func uniqueName(for baseName: String, in directory: URL, style: NameStyle)
    -> String
  {
    let normalizedBase = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
    let fileExtension = URL(fileURLWithPath: normalizedBase).pathExtension
    let hasExtension = !fileExtension.isEmpty && normalizedBase.contains(".")

    let nameWithoutExtension: String
    let extensionSuffix: String
    if hasExtension {
      nameWithoutExtension = String(normalizedBase.dropLast(fileExtension.count + 1))
      extensionSuffix = ".\(fileExtension)"
    } else {
      nameWithoutExtension = normalizedBase
      extensionSuffix = ""
    }

    let baseExists = FileManager.default.fileExists(
      atPath: directory.appendingPathComponent(normalizedBase).path)

    switch style {
    case .copy:
      guard baseExists else { return normalizedBase }
      var candidateName = "\(nameWithoutExtension) copy\(extensionSuffix)"
      var suffix = 2
      while FileManager.default.fileExists(
        atPath: directory.appendingPathComponent(candidateName).path)
      {
        candidateName = "\(nameWithoutExtension) copy \(suffix)\(extensionSuffix)"
        suffix += 1
      }
      return candidateName
    case .folder:
      guard baseExists else { return normalizedBase }
      var candidateName = "\(normalizedBase) 2"
      var suffix = 3
      while FileManager.default.fileExists(
        atPath: directory.appendingPathComponent(candidateName).path)
      {
        candidateName = "\(normalizedBase) \(suffix)"
        suffix += 1
      }
      return candidateName
    }
  }
}
