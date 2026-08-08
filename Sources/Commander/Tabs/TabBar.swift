import Foundation

final class TabBar: NSObject {
  var tabs: [Tab] = []
  var selectedIndex: Int = 0
  var onSelectTab: ((Int) -> Void)?
  var onAddTab: (() -> Void)?
}
