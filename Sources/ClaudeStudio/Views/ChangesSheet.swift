import SwiftUI

struct ChangesSheet: View {
    @Environment(\.studioTheme) private var theme
    let path: String
    let onDismiss: () -> Void

    @State private var files: [GitChanges.FileChange] = []
    @State private var selected: String?
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(theme.separator).frame(height: 1)
            if loading {
                placeholder("Reading changes…")
            } else if files.isEmpty {
                placeholder("No uncommitted changes")
            } else {
                HStack(spacing: 0) {
                    fileList.frame(width: 270)
                    Rectangle().fill(theme.separator).frame(width: 1)
                    patch
                }
            }
        }
        .frame(width: 940, height: 620)
        .background(theme.surface)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Changes")
                .font(Theme.ui(15, .semibold))
                .foregroundStyle(theme.text)
            if !files.isEmpty {
                Text("\(files.count) \(files.count == 1 ? "file" : "files")")
                    .font(Theme.ui(11.5))
                    .foregroundStyle(theme.text3)
                counts(added: files.reduce(0) { $0 + $1.added },
                       removed: files.reduce(0) { $0 + $1.removed })
            }
            Spacer()
            Text(path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(Theme.mono(10.5))
                .foregroundStyle(theme.text3)
                .lineLimit(1)
                .truncationMode(.head)
            IconButton(icon: "arrow.clockwise", help: "Refresh", action: load)
            SmallButton(title: "Done", prominent: true, action: onDismiss)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(files) { file in
                    HoverRow(selected: selected == file.path) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text((file.path as NSString).lastPathComponent)
                                .font(Theme.ui(12))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if file.untracked {
                                    Text("new").font(Theme.ui(10.5)).foregroundStyle(theme.accent)
                                }
                                counts(added: file.added, removed: file.removed)
                                Text((file.path as NSString).deletingLastPathComponent)
                                    .font(Theme.mono(10))
                                    .foregroundStyle(theme.text3)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                        }
                    }
                    .onTapGesture { selected = file.path }
                }
            }
            .padding(8)
        }
    }

    private var patch: some View {
        let lines = files.first { $0.path == selected }?.patch ?? []
        return ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line.isEmpty ? " " : line)
                        .font(Theme.mono(11.5))
                        .foregroundStyle(color(of: line))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .textSelection(.enabled)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(selected)
    }

    private func counts(added: Int, removed: Int) -> some View {
        HStack(spacing: 4) {
            Text("+\(added)").foregroundStyle(Theme.running)
            Text("−\(removed)").foregroundStyle(Theme.danger)
        }
        .font(Theme.mono(10.5))
    }

    private func color(of line: String) -> Color {
        if line.hasPrefix("@@") { return theme.accent }
        if line.hasPrefix("+") { return Theme.running }
        if line.hasPrefix("-") { return Theme.danger }
        return theme.text2
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(Theme.ui(12.5))
            .foregroundStyle(theme.text3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() {
        let path = path
        Task {
            let found = await Task.detached(priority: .userInitiated) { GitChanges.files(at: path) }.value
            files = found
            if selected == nil || !found.contains(where: { $0.path == selected }) {
                selected = found.first?.path
            }
            loading = false
        }
    }
}
