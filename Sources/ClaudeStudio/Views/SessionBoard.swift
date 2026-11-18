import SwiftUI

struct SessionBoard: View {
    @ObservedObject var model: StudioModel
    @ObservedObject private var states = SessionStates.shared
    @Environment(\.studioTheme) private var theme
    @State private var projectFilter: String?
    @State private var alphabetical = false

    private struct Column: Identifiable {
        var id: String { title }
        let title: String
        let members: Set<Attention>
        let color: Color
    }

    private let columns = [
        Column(title: "Needs you", members: [.waiting], color: Theme.waiting),
        Column(title: "Finished", members: [.done], color: Theme.waiting.opacity(0.6)),
        Column(title: "Working", members: [.working], color: Theme.running),
        Column(title: "Ready", members: [.seen, .idle], color: Theme.idle),
    ]

    private var projects: [(path: String, name: String)] {
        var seen = Set<String>()
        return states.live
            .filter { seen.insert($0.projectPath).inserted }
            .map { ($0.projectPath, $0.project) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var visible: [SessionStates.Live] {
        states.live.filter { projectFilter == nil || $0.projectPath == projectFilter }
    }

    var body: some View {
        let sessions = visible
        VStack(spacing: 10) {
            header(sessions)
            if states.live.isEmpty {
                Text("No Claude sessions are running.")
                    .font(Theme.ui(12.5))
                    .foregroundStyle(theme.text3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(columns) { column in
                        lane(column, sessions: sessions.filter { column.members.contains($0.attention) })
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.surface)
    }

    private func header(_ sessions: [SessionStates.Live]) -> some View {
        HStack(spacing: 10) {
            Menu {
                Button("All projects") { projectFilter = nil }
                Divider()
                ForEach(projects, id: \.path) { project in
                    Button(project.name) { projectFilter = project.path }
                }
            } label: {
                Text(projectFilter.flatMap { path in projects.first { $0.path == path }?.name } ?? "All projects")
                    .font(Theme.ui(12, .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Picker("", selection: $alphabetical) {
                Text("Recent").tag(false)
                Text("A–Z").tag(true)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .fixedSize()

            Spacer()

            Text("\(sessions.count) sessions · \(Set(sessions.map(\.projectPath)).count) projects")
                .font(Theme.ui(11.5))
                .foregroundStyle(theme.text3)
        }
    }

    private func lane(_ column: Column, sessions: [SessionStates.Live]) -> some View {
        let sorted = alphabetical
            ? sessions.sorted { ($0.project, $0.name) < ($1.project, $1.name) }
            : sessions.sorted { $0.at > $1.at }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                StatusDot(color: column.color, size: 7)
                Text(column.title)
                    .font(Theme.ui(12, .medium))
                    .foregroundStyle(theme.text)
                Text("\(sessions.count)")
                    .font(Theme.mono(10.5))
                    .foregroundStyle(theme.text3)
            }
            .padding(.horizontal, 2)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(sorted) { live in
                        card(live, color: column.color)
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func card(_ live: SessionStates.Live, color: Color) -> some View {
        let active = model.activeTab?.kind == .session && model.activeTab?.ref == live.tmux
        return Button { WindowManager.shared.reveal(live) } label: {
            HStack(spacing: 0) {
                Rectangle().fill(color).frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(live.name)
                            .font(Theme.ui(12.5, .medium))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(live.at.relative)
                            .font(Theme.ui(10.5))
                            .foregroundStyle(theme.text3)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    if let headline = live.headline {
                        Text(headline)
                            .font(Theme.ui(11.5))
                            .foregroundStyle(theme.text2)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(live.project)
                        .font(Theme.mono(10.5))
                        .foregroundStyle(theme.text3)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(active ? theme.hover : theme.hover.opacity(0.5)))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(active ? theme.accent.opacity(0.6) : .clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(live.question ?? "Open \(live.name) in \(live.project)")
    }
}
