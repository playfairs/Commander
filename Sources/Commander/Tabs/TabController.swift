import AppKit

final class TabController {
    typealias StateChangedHandler = (TabState) -> Void

    private(set) var state = TabState(tabs: [], selectedIndex: 0) {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: StateChangedHandler?

    var tabCount: Int {
        state.tabs.count
    }

    var selectedTab: Tab? {
        state.selectedTab
    }

    func configureTabs(_ tabs: [Tab]) {
        state = TabState(tabs: tabs, selectedIndex: max(0, tabs.isEmpty ? 0 : 0))
    }

    func addTab(_ tab: Tab) {
        var tabs = state.tabs
        tabs.append(tab)
        state = TabState(tabs: tabs, selectedIndex: tabs.count - 1)
    }

    func selectTab(at index: Int) {
        guard state.tabs.indices.contains(index) else { return }
        state = TabState(tabs: state.tabs, selectedIndex: index)
    }
}
