// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

// MARK: - what's new

/// What this version brought, shown once after updating to it (not on a first install: onboarding is the welcome then).
enum WhatsNew {
    struct Item: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    /// The version whose notes these are. A build of the same version shows nothing again.
    static let version = "1.0.1"
    static let items: [Item] = [
        Item(symbol: "bag.fill", title: "Google Play 商店",
             detail: "从“商店”标签获取游戏。从 Play 商店下载的内容（包含分卷 APK 与资源包）可在转译层中直接运行。"),
        Item(symbol: "checkmark.seal.fill", title: "Google Play 服务",
             detail: "游戏将识别 Play 服务为已存在且未登录状态，不再反复提示缺失并可直接继续运行。"),
        Item(symbol: "arrow.up.doc.fill", title: "存档备份与还原",
             detail: "在游戏详情页将存档备份为 .zip 文件，随时在当前或其它设备上快速还原。"),
        Item(symbol: "exclamationmark.bubble.fill", title: "崩溃诊断报告",
             detail: "当游戏异常退出导致 Husk 关闭时，下次启动将清晰说明原因并生成可供分享的诊断报告。"),
        Item(symbol: "checkmark.circle.fill", title: "运行兼容状态指示",
             detail: "媒体库将标明各游戏的上次运行体验：运行良好、发生崩溃或未能启动。"),
        Item(symbol: "gamecontroller.fill", title: "支持 Godot 引擎",
             detail: "基于 Godot 3 和 4 开发的游戏现已可在转译层中原生流畅运行。"),
        Item(symbol: "slider.horizontal.below.square.and.square.filled", title: "自定义虚拟按键",
             detail: "支持为每款游戏独立移动、缩放和隐藏屏幕虚拟触控按键。"),
        Item(symbol: "keyboard.fill", title: "Minecraft 输入支持",
             detail: "在 Minecraft 聊天框、告示牌及世界命名输入框中自动调出系统键盘。"),
        Item(symbol: "arrow.left.arrow.right", title: "快速切换游戏",
             detail: "退出 Husk 并切换到其它游戏时，打开 Husk 即可自动从上次退出的位置启动。"),
        Item(symbol: "puzzlepiece.extension.fill", title: "Geode 模组加载器",
             detail: "Geometry Dash 模组加载支持，内置 Geode 5，可在游戏专属设置中一键开启。"),
    ]

    private static let seenKey = "husk.whatsNew.seen"

    /// Whether to show the notes now: an update to this version, not a new install.
    static var due: Bool {
        let seen = UserDefaults.standard.string(forKey: seenKey)
        if seen == version { return false }
        if Onboarding.needed { markSeen(); return false }       // a first install: onboarding welcomes them
        return true
    }

    static func markSeen() { UserDefaults.standard.set(version, forKey: seenKey) }
}

struct WhatsNewSheet: View {
    var done: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Husk \(WhatsNew.version) 新特性").font(.largeTitle.weight(.bold))
                        Text("Husk 2.0 正式版更新内容。").foregroundStyle(.secondary)
                    }
                    .padding(.top, 36)
                    ForEach(WhatsNew.items) { item in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 26))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.headline)
                                Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
            Button(action: done) {
                Text("继续使用").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - a newer Husk

/// A newer Husk on GitHub: the releases page is asked at launch (at most twice a day) and the person is told once per release.
@MainActor
final class AppUpdates: ObservableObject {
    static let shared = AppUpdates()

    struct Release: Equatable {
        let version: String
        let page: URL
    }

    @Published var available: Release?

    private static let api = URL(string: "https://api.github.com/repos/Leviidev/Husk/releases/latest")!
    private static let checkedKey = "husk.updates.checked", dismissedKey = "husk.updates.dismissed"

    static var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func check() async {
        let d = UserDefaults.standard
        if Date().timeIntervalSince1970 - d.double(forKey: Self.checkedKey) < 12 * 3600 { return }
        var req = URLRequest(url: Self.api)
        req.timeoutInterval = 20
        req.setValue("Husk", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String,
              let page = (obj["html_url"] as? String).flatMap(URL.init(string:)) else { return }
        d.set(Date().timeIntervalSince1970, forKey: Self.checkedKey)
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard Self.newer(version, than: Self.current), d.string(forKey: Self.dismissedKey) != version else { return }
        HuskLog.log("update", "Husk \(version) is out (this is \(Self.current))")
        available = Release(version: version, page: page)
    }

    func dismiss() {
        if let v = available?.version { UserDefaults.standard.set(v, forKey: Self.dismissedKey) }
        available = nil
    }

    /// "1.0.10" is newer than "1.0.9": compared number by number.
    static func newer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}
