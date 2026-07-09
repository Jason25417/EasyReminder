import SwiftUI
import EasyReminderKit

struct ImportListPromptView: View {
    @Bindable var viewModel: ImportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导入到哪个列表？")
                .font(.headline)

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

            if viewModel.listChoice == .newList {
                TextField("新列表名", text: $viewModel.newListName)
                    .textFieldStyle(.roundedBorder)
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
