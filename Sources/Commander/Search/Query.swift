import Foundation

struct SearchQuery: Equatable {
    let term: String
    let fullSearch: Bool

    init(term: String, fullSearch: Bool = false) {
        self.term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fullSearch = fullSearch
    }

    var isValid: Bool {
        !term.isEmpty
    }
}
