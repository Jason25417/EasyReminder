import SwiftUI

struct ChangelogView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("更新日志").font(.title2).bold()
                Spacer()
                Button("完成") { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Changelog.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("v\(entry.version)").font(.headline)
                                Text(entry.date).font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(entry.changes, id: \.self) { c in
                                Text("• \(c)").font(.callout)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(width: 440, height: 380)
    }
}
