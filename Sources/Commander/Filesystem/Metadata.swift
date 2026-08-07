import Darwin
import Foundation

public enum Metadata {
  public static func formattedMetadata(for url: URL) -> String {
    var lines: [String] = []

    let resourceKeys: Set<URLResourceKey> = [
      .nameKey,
      .isDirectoryKey,
      .contentTypeKey,
      .fileSizeKey,
      .creationDateKey,
      .contentModificationDateKey,
      .isHiddenKey,
      .isReadableKey,
      .isWritableKey,
      .isExecutableKey,
      .isAliasFileKey,
      .isPackageKey,
    ]

    let resourceValues = try? url.resourceValues(forKeys: resourceKeys)

    func append(_ label: String, _ value: String?) {
      lines.append("\(label): \(value ?? "—")")
    }

    append("Name", resourceValues?.name ?? url.lastPathComponent)
    append("Path", url.path)
    append("Kind", kindLabel(for: url, resourceValues: resourceValues))

    if let isDirectory = resourceValues?.isDirectory, isDirectory {
      append("Size", "—")
    } else {
      append("Size", sizeLabel(for: resourceValues, url: url))
    }

    append("Created", dateLabel(resourceValues?.creationDate))
    append("Modified", dateLabel(resourceValues?.contentModificationDate))
    append("Type", typeLabel(resourceValues))
    append("Hidden", boolLabel(resourceValues?.isHidden))
    append("Readable", boolLabel(resourceValues?.isReadable))
    append("Writable", boolLabel(resourceValues?.isWritable))
    append("Executable", boolLabel(resourceValues?.isExecutable))
    append("Alias", boolLabel(resourceValues?.isAliasFile))
    append("Package", boolLabel(resourceValues?.isPackage))

    if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
      append("Owner", attributes[.ownerAccountName] as? String)
      append("Group", attributes[.groupOwnerAccountName] as? String)
      append("Permissions", permissionLabel(attributes[.posixPermissions] as? NSNumber))
      append("File Number", stringLabel(attributes[.systemFileNumber]))
      append("Device ID", stringLabel(attributes[.systemNumber]))
    }

    return lines.joined(separator: "\n")
  }

  private static func kindLabel(for url: URL, resourceValues: URLResourceValues?) -> String {
    if let isDirectory = resourceValues?.isDirectory, isDirectory {
      return "Folder"
    }
    if let typeIdentifier = resourceValues?.contentType?.identifier {
      return typeIdentifier
    }
    return url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased()
  }

  private static func sizeLabel(for resourceValues: URLResourceValues?, url: URL) -> String {
    if let fileSize = resourceValues?.fileSize {
      return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    return stringLabel(
      (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)
      ?? "—"
  }

  private static func dateLabel(_ date: Date?) -> String? {
    guard let date else { return nil }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private static func typeLabel(_ resourceValues: URLResourceValues?) -> String? {
    if let contentType = resourceValues?.contentType {
      return contentType.identifier
    }
    return nil
  }

  private static func boolLabel(_ value: Bool?) -> String {
    guard let value else { return "—" }
    return value ? "Yes" : "No"
  }

  private static func stringLabel(_ value: Any?) -> String? {
    if let number = value as? NSNumber {
      return number.stringValue
    }
    if let string = value as? String {
      return string
    }
    return nil
  }

  private static func permissionLabel(_ value: NSNumber?) -> String? {
    guard let value else { return nil }
    let mode = value.uint16Value
    let type = mode & S_IFMT
    let fileType: String
    switch type {
    case S_IFDIR: fileType = "d"
    case S_IFREG: fileType = "-"
    case S_IFLNK: fileType = "l"
    default: fileType = "?"
    }

    var permissionString = ""
    let flags: [(UInt16, String)] = [
      (S_IRUSR, "r"), (S_IWUSR, "w"), (S_IXUSR, "x"),
      (S_IRGRP, "r"), (S_IWGRP, "w"), (S_IXGRP, "x"),
      (S_IROTH, "r"), (S_IWOTH, "w"), (S_IXOTH, "x"),
    ]

    for (mask, symbol) in flags {
      permissionString += (mode & mask) != 0 ? symbol : "-"
    }

    return "\(fileType)\(permissionString)"
  }
}
