import XCTest

@testable import Commander

final class CommanderTests: XCTestCase {
  func testDuplicateOperationCreatesUniqueDestinationName() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    let sourceURL = tempDirectory.appendingPathComponent("Report.txt")
    try "hello".write(to: sourceURL, atomically: true, encoding: .utf8)

    defer {
      try? FileManager.default.removeItem(at: tempDirectory)
    }

    let duplicatedURL = try FileSystemOperations.duplicateItem(at: sourceURL, in: tempDirectory)

    XCTAssertTrue(FileManager.default.fileExists(atPath: duplicatedURL.path))
    XCTAssertEqual(duplicatedURL.lastPathComponent, "Report copy.txt")
  }

  func testCreateFolderOperationAddsNumericSuffixWhenNeeded() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    defer {
      try? FileManager.default.removeItem(at: tempDirectory)
    }

    let firstFolder = try FileSystemOperations.createFolder(named: "New Folder", in: tempDirectory)
    let secondFolder = try FileSystemOperations.createFolder(named: "New Folder", in: tempDirectory)

    XCTAssertTrue(FileManager.default.fileExists(atPath: firstFolder.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: secondFolder.path))
    XCTAssertEqual(secondFolder.lastPathComponent, "New Folder 2")
  }
}
