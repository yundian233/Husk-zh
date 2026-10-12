// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

/// The FAQ tab: common problems and what to do about them, so a user stuck on JIT or on an app
/// that will not open has an answer without leaving Husk.
struct FAQTab: View {
    @State private var query = ""

    private var sections: [FAQ.Section] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return FAQ.sections }
        return FAQ.sections.compactMap { s in
            let items = s.items.filter { $0.question.localizedCaseInsensitiveContains(q) || $0.answer.localizedCaseInsensitiveContains(q) }
            return items.isEmpty ? nil : FAQ.Section(title: s.title, symbol: s.symbol, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { s in
                    Section {
                        ForEach(s.items) { item in FAQRow(item: item, expanded: !query.isEmpty) }
                    } header: {
                        Label(s.title, systemImage: s.symbol)
                    }
                }
                if sections.isEmpty {
                    Text("未找到与“\(query)”匹配的问题。可打开“设置 › 关于 › 打开控制台”查看 Husk 正在运行的内容。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("常见问题")
            .searchable(text: $query, prompt: "搜索问题")
        }
    }
}

private struct FAQRow: View {
    let item: FAQ.Item
    var expanded: Bool
    @State private var open = false

    var body: some View {
        DisclosureGroup(isExpanded: Binding(get: { open || expanded }, set: { open = $0 })) {
            Text(.init(item.answer))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
        } label: {
            Text(item.question).font(.body.weight(.medium))
        }
    }
}

enum FAQ {
    struct Item: Identifiable { let question: String; let answer: String; var id: String { question } }
    struct Section: Identifiable { let title: String; let symbol: String; let items: [Item]; var id: String { title } }

    static let sections: [Section] = [
        Section(title: "JIT 即时编译", symbol: "bolt.fill", items: [
            Item(question: "什么是 JIT，为什么 Husk 必须需要它？",
                 answer: "Android 应用和游戏在运行时需要即时编译代码，这要求内存具备可写且可执行权限。"
                       + "iOS 仅在有调试器附加到应用时才允许此权限。开启 JIT 即为瞬间挂载调试器。"
                       + "若没有 JIT，Husk 可以正常浏览应用库，但无法启动 Android 虚拟机或运行游戏。"),
            Item(question: "我应该选用哪种方式开启 JIT？",
                 answer: "• **iOS 27 或更高版本：** 设置 › JIT › 在本机配对。无需电脑。\n"
                       + "• **iOS 26：** 内置 StikJIT（使用电脑生成的配对文件）+ LocalDevVPN。\n"
                       + "• **旧版 iOS 或 LiveContainer 内的 Husk：** 使用 StikDebug 应用。\n"
                       + "• **使用 TrollStore 安装：** 在 TrollStore 中开启 URL Scheme 设置直接激活。\n"
                       + "• **Dopamine 等越狱设备：** 在越狱设置中直接开启 App 的 JIT 选项。"),
            Item(question: "StikJIT 提示无法连接，或启用 JIT 失败怎么办？",
                 answer: "1. 确保已安装并连接 **LocalDevVPN**（状态栏应显示 VPN 图标）。\n"
                       + "2. 手机 Wi-Fi 必须保持开启状态（即使数据不出本机）。\n"
                       + "3. 必须已启用 **开发者模式**（系统设置 › 隐私与安全性 › 开发者模式）。\n"
                       + "4. 首次使用时 Husk 会下载 Apple 开发者磁盘映像 (DDI)，需要约 1 分钟，请耐心等待完成。\n"
                       + "5. 仍失败时，可开关一次 LocalDevVPN 并重新配对。"),
            Item(question: "开发者模式中没有出现“与 Husk 配对”选项？",
                 answer: "请先在 Husk 中点击 **开始配对**，并在弹窗询问时允许 **本地网络** 权限。"
                       + "如果之前误点了拒绝，请在系统设置 › 隐私与安全性 › 本地网络 › Husk 中重新打开。同时确保 Wi-Fi 开启且开发者模式已就绪。"),
            Item(question: "我的配对文件失效了？",
                 answer: "当重置了 iPhone 的信任设置或进行 iOS 系统更新后，配对文件可能会失效。"
                       + "重新制作一份新配对文件，或者在“设置 › JIT”中重新导入即可。"),
            Item(question: "打开了 StikDebug，但 JIT 依然显示未开启？",
                 answer: "单独打开 StikDebug 检查是否已导入配对文件且 LocalDevVPN 是否已连接。"
                       + "建议将 StikDebug 更新到最新版本。Husk 会自动向 StikDebug 发送脚本，无需手动配置。"),
            Item(question: "为什么每次启动都需要重新开启 JIT？",
                 answer: "JIT 权限与 Husk 进程的生命周期一致。当 iOS 在后台杀死 Husk 或手动上滑退出应用后，"
                       + "下次打开都需要重新激活 JIT。通过本机配对或配对文件，仅需一键轻点即可完成。"),
            Item(question: "可以在没有 JIT 的情况下使用 Husk 吗？",
                 answer: "可以浏览和导入应用文件，但无法运行任何 Android 内容。所有游戏与应用运行均必须依赖 JIT。"),
        ]),
        Section(title: "Husk 应用本身", symbol: "app.badge", items: [
            Item(question: "Husk 完全打不开或闪退？",
                 answer: "• **打开后立即闪退：** 签名证书可能已过期（免费个人证书通常为 7 天）。请使用自签工具重新签名安装，已导入的应用和存档会被完整保留。\n"
                       + "• **提示“不受信任的开发者”：** 前往系统设置 › 通用 › VPN 与设备管理，信任对应的证书即可。\n"
                       + "• **提示需要开发者模式：** 前往系统设置 › 隐私与安全性，开启“开发者模式”并按提示重启手机。"),
            Item(question: "玩游戏时 Husk 突然闪退关闭了？",
                 answer: "再次打开 Husk 时会弹出崩溃诊断说明，并提供可分享的诊断报告。通常是因为设备运行内存不足 (RAM OOM) "
                       + "或触及了转译层尚未支持的特性。建议清理后台多余应用后再试，若持续发生可分享崩溃报告。"),
            Item(question: "如何获取日志以反馈问题？",
                 answer: "在应用库中打开该应用的详情页，点击 **分享报告**。如需查看 Husk 自身日志，请前往 "
                       + "设置 › 关于 › **打开控制台**。在其中开启 **开发者信息** 可查看更详尽的技术追踪。"),
            Item(question: "如何更新 Husk？",
                 answer: "当发布新版时 Husk 会在主页提醒。使用同一自签工具直接将新版 IPA 覆盖安装即可，"
                       + "你的应用库、游戏及存档数据均会完整保留。"),
        ]),
        Section(title: "应用与游戏运行", symbol: "gamecontroller.fill", items: [
            Item(question: "某个应用打不开？",
                 answer: "在应用库中打开其详情页，Husk 会显示无法启动的具体原因：\n"
                       + "• **受保护应用：** 应用检测了真实真机环境、反作弊或加固保护。Husk 暂无法绕过此类检测。\n"
                       + "• **CPU 架构不匹配：** 该 APK 仅包含 32 位代码。请寻找 arm64 (arm64-v8a) 架构的版本。\n"
                       + "• **应用不完整或缺少数据包：** 需要分卷 split APK 或 OBB 数据包。请导入完整的 .apks、.xapk 或 .apkm 文件。\n"
                       + "• **依赖 Google 服务：** 该应用强依赖 Google 账号或 Play 服务。\n"
                       + "• **遇到了 Husk 暂未支持的接口：** 请点击分享报告以便后续适配完善。"),
            Item(question: "启动游戏后一直黑屏？",
                 answer: "大型游戏首次启动时需要编译代码并解压资源，可能需要最多 1 分钟左右。"
                       + "若超过 1 分钟仍黑屏，请退出后重新尝试一次；若仍无效可查看崩溃报告。"),
            Item(question: "修改版/破解版 APK 闪退？",
                 answer: "部分修改版 APK 会打包自身的防篡改检测库，这类修改更容易引起兼容性崩溃。"
                       + "建议使用来自官方或 APKMirror 的原版 APK。"),
            Item(question: "支持导入哪些格式？",
                 answer: "支持 .apk，以及分卷安装包 .apks、.xapk、.apkm。可直接通过系统“分享”发送到 Husk，或从“文件”标签页及应用库的“+”号导入。"),
            Item(question: "游戏运行卡顿或手机发热？",
                 answer: "请关闭后台其他占用资源的应用。虽然游戏为原生转译运行，但部分计算由 CPU 模拟执行，负载较高。"
                       + "开启“低电量模式”也会限制性能，建议关闭低电量模式。"),
            Item(question: "支持外接游戏手柄吗？",
                 answer: "支持。在 iPhone 系统蓝牙设置中配对连接手柄后，支持手柄控制的游戏会自动识别。"),
            Item(question: "可以在游戏运行时继续使用 Husk 吗？",
                 answer: "在“设置”中开启 **在窗口中打开应用** 即可。游戏将以悬浮窗口呈现，可任意移动、缩放和最小化。"),
            Item(question: "无法使用 Google 账号登录？",
                 answer: "Husk 目前未内置完整的 Google Play 服务框架，点击“Sign in with Google”可能会失败。建议使用邮箱或其他账号方式登录。"),
        ]),
        Section(title: "存档与存储空间", symbol: "externaldrive.fill", items: [
            Item(question: "我的游戏存档保存在哪里？",
                 answer: "每个应用的数据都保存在 Husk 内部。在游戏页面中，点击 **备份游戏存档** 可导出为 .zip 文件，"
                       + "点击 **恢复游戏存档** 即可还原，也可导入到其他 iPhone 上继续游玩。"),
            Item(question: "Husk 占用了大量手机空间？",
                 answer: "导入的应用和生成的数据都在 Husk 目录下。对于不再游玩的游戏，可在其详情页中将其删除。"
                       + "完整的 Android 系统镜像约额外占用 2 GB 存储。"),
        ]),
        Section(title: "Android 虚拟机", symbol: "cpu", items: [
            Item(question: "“转译层应用”与“Android 虚拟机”有何区别？",
                 answer: "绝大多数游戏通过转译层（Translation Layer）直接在 iPhone 上高速原生运行。"
                       + "完整的 Android 系统则是虚拟出来的系统环境，运行速度较慢，主要用于转译层无法直接支持的应用（如 Termux 等）。"),
            Item(question: "Android 虚拟机启动很慢？",
                 answer: "首次启动需要解压镜像并冷启动，耗时数分钟。"
                       + "之后 Husk 会自动恢复快照，启动速度仅需数秒。"),
        ]),
    ]
}
