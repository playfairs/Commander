import Foundation

struct TabState {
  private(set) var tabs: [Tab]
  private(set) var selectedIndex: Int

  init(tabs: [Tab], selectedIndex: Int = 0) {
    self.tabs = tabs
    self.selectedIndex = tabs.indices.contains(selectedIndex) ? selectedIndex : 0
  }

  var selectedTab: Tab? {
    guard tabs.indices.contains(selectedIndex) else { return nil }
    return tabs[selectedIndex]
  }

  var tabTitles: [String] {
    tabs.map { $0.title }
  }
}
