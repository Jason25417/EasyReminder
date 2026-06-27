import SwiftUI

struct ContentView: View {
    @State private var count = 0          // 当前数字，从 0 开始
    @State private var inputText = ""     // 输入框里的文字
    @State private var errorMessage = ""  // 出错时显示的提示

    var body: some View {
        VStack(spacing: 20) {
            // 图片窗口：用系统数字图标显示当前数字
            Image(systemName: "\(min(count, 50)).circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(.blue)

            // 文本窗口：显示当前数字
            Text("当前数字：\(count)")
                .font(.title)

            // 按钮：点一下 +1
            Button("+1") {
                count += 1
                errorMessage = ""
            }
            .buttonStyle(.borderedProminent)

            // 输入框：只接受 "1"，回车确认
            TextField("只能输入 1，回车确认", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onSubmit {
                    if inputText == "1" {
                        count += 1
                        errorMessage = ""
                    } else {
                        errorMessage = "error"
                    }
                    inputText = ""   // 处理完清空输入框
                }

            // 出错提示（只有出错时才显示）
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .padding(40)
        .frame(minWidth: 360, minHeight: 420)
    }
}

#Preview {
    ContentView()
}
