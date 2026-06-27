import SwiftUI
import UniformTypeIdentifiers

/// 用于 fileExporter 写出 .ics 文件的简单文档。
struct ICSDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "ics") ?? .text]
    }

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
