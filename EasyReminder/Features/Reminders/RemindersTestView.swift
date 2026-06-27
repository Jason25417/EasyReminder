import SwiftUI

struct RemindersTestView: View {
    @State private var viewModel: RemindersViewModel

    init(viewModel: RemindersViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("M1：提醒事项权限 + 写入测试")
                .font(.headline)

            Button("建一条测试提醒") {
                Task { await viewModel.addTestReminder() }
            }
            .buttonStyle(.borderedProminent)

            Text(viewModel.status)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(minWidth: 380, minHeight: 220)
    }
}
