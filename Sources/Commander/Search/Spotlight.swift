import Foundation

struct Spotlight {
    static func searchRoots(for currentURL: URL, fullSearch: Bool) -> [URL] {
        var roots: [URL] = [currentURL]

        if fullSearch {
            let home = FileManager.default.homeDirectoryForCurrentUser
            roots.append(home)

            let volumesURL = URL(fileURLWithPath: "/Volumes")
            if FileManager.default.fileExists(atPath: volumesURL.path) {
                roots.append(volumesURL)
            }
        } else {
            var url = currentURL
            while let parent = parentURL(for: url) {
                roots.append(parent)
                url = parent
            }
        }

        return roots
    }

    static func enumeratorOptions(showHiddenFiles: Bool) -> FileManager.DirectoryEnumerationOptions {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !showHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }
        return options
    }

    private static func parentURL(for url: URL) -> URL? {
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path { return nil }
        if url.path == "/" { return nil }
        if url.pathComponents.count == 3 && url.pathComponents[1] == "Volumes" { return nil }
        return parent
    }
}
