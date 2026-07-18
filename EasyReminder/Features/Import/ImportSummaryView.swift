import SwiftUI

/// 导入完成后的内容摘要：列表只留标题+一行时间，点条目弹详情。
struct ImportSummaryView: View {
    let summary: ImportSummary
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEntry: ImportSummary.Entry?

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
        .frame(width: 460, height: 440)
        #endif
        .sheet(item: $selectedEntry) { entry in
            ImportEntryDetailView(entry: entry)
        }
    }

    private func section(title: String, systemImage: String,
                         entries: [ImportSummary.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(entries) { e in
                Button {
                    selectedEntry = e
                } label: {
                    row(e)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ e: ImportSummary.Entry) -> some View {
        HStack(spacing: 10) {
            if e.isEvent {
                miniCalendar(month: e.monthText, day: e.dayText)
            } else {
                ZStack {
                    Circle().fill(.blue.opacity(0.15))
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(e.title).lineLimit(1)
                if let sub = e.subtitle {
                    Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private func miniCalendar(month: String?, day: String?) -> some View {
        VStack(spacing: 0) {
            Text(month ?? "—")
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 10)
                .background(.indigo)
            Text(day ?? "?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.indigo)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.indigo.opacity(0.12))
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// 单条导入内容的完整详情。
struct ImportEntryDetailView: View {
    let entry: ImportSummary.Entry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.title).font(.headline).lineLimit(2)
                Spacer()
                Button("关闭") { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.detailRows) { row in
                        HStack(alignment: .top, spacing: 12) {
                            Text(row.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 56, alignment: .leading)
                            Text(row.value)
                                .font(.callout)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 380, height: 320)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }
}
