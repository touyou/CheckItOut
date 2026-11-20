//
//  LicensesView.swift
//  Checkitout
//
//  Third-party licenses bundled with the app (Licenses.txt).
//

import SwiftUI

struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss

    // 依存やフォントを足したら Licenses.txt も更新する
    private let text: String = {
        guard let url = Bundle.main.url(forResource: "Licenses", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(verbatim: text)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("オープンソースライセンス")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
        }
    }
}
