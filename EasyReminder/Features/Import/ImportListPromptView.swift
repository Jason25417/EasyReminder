import SwiftUI
import EasyReminderKit

struct ImportListPromptView: View {
    @Bindable var viewModel: ImportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导入到哪里？")
                .font(.headline)

            if viewModel.hasPendingTodos {
                VStack(alignment: .leading, spacing: 6) {
                    Text("待办 → 提醒事项列表").font(.subheadline).foregroundStyle(.secondary)
                    Picker("目标列表", selection: $viewModel.listChoice) {
                        Text("默认列表").tag(ImportViewModel.ListChoice.defaultList)
                        if !viewModel.availableLists.isEmpty {
                            Divider()
                            ForEach(viewModel.availableLists) { list in
                                Text(list.title).tag(ImportViewModel.ListChoice.existing(list.title))
                            }
                        }
                        Divider()
                        Text("新建列表…").tag(ImportViewModel.ListChoice.newList)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if viewModel.listChoice == .newList {
                        TextField("新列表名", text: $viewModel.newListName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            if viewModel.hasPendingEvents {
                VStack(alignment: .leading, spacing: 6) {
                    Text("事件 → 日历").font(.subheadline).foregroundStyle(.secondary)
                    Picker("目标日历", selection: $viewModel.calendarChoice) {
                        Text("默认日历").tag(ImportViewModel.CalendarChoice.defaultCalendar)
                        if !viewModel.availableCalendars.isEmpty {
                            Divider()
                            ForEach(viewModel.availableCalendars, id: \.self) { name in
                                Text(name).tag(ImportViewModel.CalendarChoice.existing(name))
                            }
                        }
                        Divider()
                        Text("新建日历…").tag(ImportViewModel.CalendarChoice.newCalendar)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if viewModel.calendarChoice == .newCalendar {
                        TextField("新日历名", text: $viewModel.newCalendarName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack {
                Spacer()
                Button("取消") { viewModel.cancelImport() }
                Button("导入") { Task { await viewModel.confirmImport() } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 380)
        #endif
    }
}
