import SwiftUI

struct SidebarView: View {
  enum SectionItem: String, CaseIterable, Identifiable {
    case selections = "Selections"
    case recents = "Recents"
    case settings = "Settings"
    case about = "About"

    var id: String { rawValue }
    var icon: String {
      switch self {
      case .selections: return "folder"
      case .recents: return "clock"
      case .settings: return "gearshape"
      case .about: return "info.circle"
      }
    }
  }

  @ObservedObject var selectionStore: SelectionsStore
  let openSelection: (URL) -> Void
  @State private var selectedSection: SectionItem = .selections

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Sections")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.top, 10)

      VStack(spacing: 0) {
        ForEach(SectionItem.allCases) { section in
          Button(action: { selectedSection = section }) {
            HStack(spacing: 10) {
              Image(systemName: section.icon)
                .frame(width: 18)
              Text(section.rawValue)
                .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
              Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
              selectedSection == section
                ? Color(nsColor: .selectedControlColor).opacity(0.12) : .clear
            )
            .cornerRadius(8)
          }
          .buttonStyle(.plain)
          .foregroundColor(.primary)
        }
      }
      .padding(.top, 8)
      .padding(.horizontal, 2)

      Divider()
        .padding(.vertical, 10)

      Group {
        switch selectedSection {
        case .selections:
          if selectionStore.selections.isEmpty {
            Text("No selections saved yet.")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 12)
              .padding(.top, 6)
          } else {
            List(selectionStore.selections, id: \.self) { selection in
              Button(action: {
                openSelection(URL(fileURLWithPath: selection))
              }) {
                HStack(spacing: 8) {
                  Image(systemName: "folder")
                    .frame(width: 18)
                  Text(URL(fileURLWithPath: selection).lastPathComponent)
                    .font(.system(size: 13))
                    .lineLimit(1)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.plain)
              .help(selection)
            }
            .listStyle(.sidebar)
            .padding(.horizontal, 4)
          }

        case .recents:
          VStack(alignment: .leading, spacing: 10) {
            Label("No recent items yet.", systemImage: "clock.arrow.circlepath")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 12)
              .padding(.top, 6)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

        case .settings:
          VStack(alignment: .leading, spacing: 10) {
            Label("Show hidden files", systemImage: "eye")
              .font(.system(size: 13))
              .foregroundStyle(.primary)
              .padding(.horizontal, 12)
              .padding(.top, 6)
            Label("Open preferences here", systemImage: "slider.horizontal.3")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 12)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

        case .about:
          VStack(alignment: .leading, spacing: 10) {
            Label("Commander", systemImage: "app")
              .font(.system(size: 13, weight: .semibold))
              .padding(.horizontal, 12)
              .padding(.top, 6)
            Text("A fast dual-pane commander for macOS.")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 12)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      Spacer()
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }
}
