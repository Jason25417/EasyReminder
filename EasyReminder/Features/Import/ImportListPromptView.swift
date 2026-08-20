import SwiftUI
import EasyReminderKit

struct ImportListPromptView: View {
    @Bindable var viewModel: ImportViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("导入到哪里？")
                    .font(.headline)

                if viewModel.hasPendingTodos {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("待办 → 提醒事项列表").font(.subheadline).foregroundStyle(.secondary)
                        if viewModel.listAccessDenied {
                            deniedNote(String(localized: "提醒事项权限被拒绝。请到「系统设置 → 隐私与安全性 → 提醒事项」允许本 App 访问，再重新导入。"))
                        } else {
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
                }

                if viewModel.hasPendingEvents {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("事件 → 日历").font(.subheadline).foregroundStyle(.secondary)
                        if viewModel.calendarAccessDenied {
                            deniedNote(String(localized: "日历权限被拒绝。请到「系统设置 → 隐私与安全性 → 日历」允许本 App 访问，再重新导入。"))
                        } else {
                            Picker("目标日历", selection: $viewModel.calendarChoice) {
                                Text("默认日历").tag(ImportViewModel.CalendarChoice.defaultCalendar)
                                if !viewModel.availableCalendars.isEmpty {
                                    Divider()
                                    ForEach(viewModel.availableCalendars) { cal in
                                        Text(calendarLabel(cal))
                                            .tag(ImportViewModel.CalendarChoice.existing(cal.id))
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
                }

                HStack {
                    Spacer()
                    Button("取消") { viewModel.cancelImport() }
                    Button("导入") { Task { await viewModel.confirmImport() } }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        #if os(macOS)
        .frame(width: 380)
        #else
        .presentationDetents([.medium])
        #endif
    }

    /// 同名日历带上账户名区分（如「学校 — iCloud」）。
    private func calendarLabel(_ cal: CalendarInfo) -> String {
        let duplicated = viewModel.availableCalendars.filter { $0.title == cal.title }.count > 1
        return duplicated && !cal.account.isEmpty ? "\(cal.title) — \(cal.account)" : cal.title
    }

    private func deniedNote(_ text: String) -> some View {
        Label {
            Text(text).font(.callout)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
