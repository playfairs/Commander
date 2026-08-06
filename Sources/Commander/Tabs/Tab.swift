import Foundation

struct Tab: Identifiable, Equatable {
  let id: UUID
  var title: String
  var leftRootURL: URL
  var rightRootURL: URL

  init(title: String, leftRootURL: URL, rightRootURL: URL, id: UUID = UUID()) {
    self.id = id
    self.title = title
    self.leftRootURL = leftRootURL
    self.rightRootURL = rightRootURL
  }
}
