import SwiftUI

/// 导入完成后的内容摘要：这次导入了哪些待办 / 事件、去了哪里。
struct ImportSummaryView: View {
    let summary: ImportSummary
    @Environment(\.dismiss) private var dismiss

    private var todos: [ImportSummary.Entry] { summary.entries.filter { !$0.isEvent } }
    private var events: [ImportSummary.Entry] { summary.entries.filter(\.isEvent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("导入完成").font(.title2).bold()
                Spacer()
                Button("完成") { dismiss() }
            }
            Text(summary.headline)
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !todos.isEmpty {
                        section(title: String(localized: "待办（\(todos.count)）"),
                                systemImage: "checklist", entries: todos)
                    }
                    if !events.isEmpty {
                        section(title: String(localized: "事件（\(events.count)）"),
                                systemImage: "calendar", entries: events)
                    }
                    if let note = summary.ignoredNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 460, height: 420)
        #endif
    }

    private func section(title: String, systemImage: String,
                         entries: [ImportSummary.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            ForEach(entries) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.title)
                    if let d = e.dateText {
                        Text(d).font(.caption).foregroundStyle(.secondary)
                    }
                    if let detail = e.detail {
                        Text(detail).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 3)
                Divider()
            }
        }
    }
}
