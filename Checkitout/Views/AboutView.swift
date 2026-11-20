//
//  AboutView.swift
//  Checkitout
//
//  The 「チェケラについて」 sheet: version, feedback and legal links. The app has a single
//  setting (in the gear menu), so this is opened from that menu instead of a settings screen.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AboutHeader()
                }

                Section("フィードバック") {
                    AboutLinkRow(title: "アプリを評価", systemImage: "star", destination: AppLinks.writeReview)
                    AboutLinkRow(title: "機能要望・不具合報告", systemImage: "envelope", destination: AppLinks.support)
                    ShareLink(item: AppLinks.appStore) {
                        Label("アプリを共有", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    AboutLinkRow(title: "開発者について", systemImage: "person", destination: AppLinks.developer)
                }

                Section {
                    AboutLinkRow(title: "プライバシーポリシー", systemImage: "hand.raised", destination: AppLinks.privacy)
                    NavigationLink {
                        LicensesView()
                    } label: {
                        Label("オープンソースライセンス", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("チェケラについて")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
        }
    }
}

private struct AboutHeader: View {
    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: "チェケラ")
                .font(.brand(24))
            Text("バージョン \(AppLinks.version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("日本で個人が開発しています。")
                .font(.footnote)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// A row that leaves the app (Safari or the App Store), marked with an arrow.
private struct AboutLinkRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

enum AppLinks {
    static let appStore = URL(string: "https://apps.apple.com/app/id1209866956")!
    static let writeReview = URL(string: "https://apps.apple.com/app/id1209866956?action=write-review")!
    static let support = URL(string: "https://touyou.dev/checkitout/support")!
    static let privacy = URL(string: "https://touyou.dev/checkitout/privacy")!
    static let developer = URL(string: "https://touyou.dev")!

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }
}
