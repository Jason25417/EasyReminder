import SwiftUI
import UniformTypeIdentifiers
import EasyReminderKit

struct ExportView: View {
    @State private var viewModel: ExportViewModel

    init(viewModel: ExportViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("从提醒事项导出为 ICS")
                .font(.headline)

            HStack(alignment: .top, spacing: 24) {
                // 左：目标列表
                VStack(alignment: .leading, spacing: 6) {
                    Text("目标列表").font(.subheadline).foregroundStyle(.secondary)
                    Picker("目标列表", selection: $viewModel.selectedID) {
                        ForEach(viewModel.targets) { target in
                            Text(target.title).tag(Optional(target.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }

                // 右：导出项目（多选）
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("导出项目").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Toggle("全选", isOn: Binding(
                            get: { viewModel.allSelected },
                            set: { viewModel.setSelectAll($0) }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .disabled(viewModel.items.isEmpty)
                    }
                    itemList
                }
            }

            Button("导出为 ICS…") { Task { await viewModel.prepareExport() } }
                .buttonStyle(.borderedProminent)

            Text(viewModel.status)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(30)
        .frame(minWidth: 540, minHeight: 380)
        .task { await viewModel.load() }
        .onChange(of: viewModel.selectedID) { Task { await viewModel.loadItems() } }
        .fileExporter(isPresented: $viewModel.showingExporter,
                      document: viewModel.document,
                      contentType: Self.icsType,
                      defaultFilename: viewModel.suggestedName) { result in
            viewModel.exportCompleted(result)
        }
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: viewModel.selectedItemIDs.contains(item.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.selectedItemIDs.contains(item.id) ? .blue : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).lineLimit(1)
                            if let due = item.dueDate {
                                Text(Self.dateText(due)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.toggle(item.id) }
                    Divider()
                }
            }
        }
        .frame(width: 260, height: 200)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
    }

    private static var icsType: UTType { UTType(filenameExtension: "ics") ?? .text }

    private static func dateText(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}
