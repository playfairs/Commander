import Foundation

final class SearchController {
    static func search(query: SearchQuery, from currentURL: URL, showHiddenFiles: Bool, resultLimit: Int = 200) async -> [URL] {
        guard query.isValid else { return [] }

        let searchTerm = query.term.lowercased()
        let roots = Spotlight.searchRoots(for: currentURL, fullSearch: query.fullSearch)
        let options = Spotlight.enumeratorOptions(showHiddenFiles: showHiddenFiles)

        return await Task.detached {
            let fileManager = FileManager()
            var matches: [URL] = []
            for base in roots {
                let enumerator = fileManager.enumerator(at: base, includingPropertiesForKeys: [.isDirectoryKey], options: options, errorHandler: nil)
                while let item = enumerator?.nextObject() as? URL {
                    if matches.count >= resultLimit { break }
                    if item.lastPathComponent.lowercased().contains(searchTerm) {
                        matches.append(item)
                    }
                }
                if matches.count >= resultLimit { break }
            }
            return matches
        }.value
    }
}
