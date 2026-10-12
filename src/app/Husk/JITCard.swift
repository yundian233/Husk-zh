// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

/// The way to turn on JIT, said plainly: StikJIT is built into Husk, and it is the recommended way.
///
/// Android and the Translation Layer's games both need memory they can write and then execute, which on iOS takes an attached
/// debugger. Husk can be that debugger itself -- StikJIT, in the app, with no computer and no other app -- so this is the first
/// thing shown wherever JIT is missing, with the other methods one tap further. Once JIT is on it shrinks to a line saying so.
struct JITCard: View {
    @ObservedObject private var jit = JITCoordinator.shared
    /// One line instead of a card: for the library, where it sits above the games rather than being the page.
    var compact = false

    private var isOn: Bool { JITBootstrap.ready }

    /// The way the card offers: StikJIT where Husk has it (iOS 26 and later), and otherwise whatever this device has -- TrollStore, a
    /// jailbreak -- since StikJIT cannot run on an iOS before 26.
    private var offered: JITMethod {
        if HuskBuiltInJIT.isAvailable { return .builtIn }
        let resolved = jit.resolvedMethod
        return resolved == .builtIn ? .builtIn : resolved
    }

    var body: some View {
        if compact {
            if !isOn { strip }
        } else {
            Group {
                if isOn { on } else { off }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    /// JIT is off, the way to turn it on, and nothing else. The full story is a tap on the words away.
    private var strip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.16), in: Circle())
                Button { jit.showSetup = true } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("JIT 未开启").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text(jit.busy ? (jit.status ?? "正在开启 JIT…") : "运行游戏需要 JIT 支持。通过 \(offered == .builtIn ? "内置 StikJIT" : offered.title) 即可开启。")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if jit.busy {
                    ProgressView()
                } else {
                    Button {
                        if offered == .builtIn, HuskBuiltInJIT.isAvailable { jit.method = .builtIn }
                        jit.enable()
                    } label: {
                        Text("开启 JIT")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(Color.accentColor, in: Capsule())
                    }
                    .buttonStyle(CardButtonStyle())
                }
            }
            if let error = jit.error {
                Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var explanation: String {
        switch offered {
        case .trollStore:
            return "TrollStore 可直接免电脑为 Husk 开启 JIT。请在 TrollStore 设置中确保已启用“URL Scheme”。"
        case .jailbreak:
            return "在越狱设备上，可在 Dopamine 设置中开启“允许应用 JIT”，然后重新打开 Husk 即可。"
        case .stikDebug:
            return "已安装 StikDebug，Husk 将跳转至 StikDebug 以开启 JIT。"
        default:
            return "Husk 已内置 StikJIT。你可以直接在此处开启 JIT — 免电脑、免其他 App。游戏与 Android 虚拟机均需要此权限。"
        }
    }

    private var buttonTitle: String {
        switch offered {
        case .trollStore: return "使用 TrollStore 开启 JIT"
        case .jailbreak: return "如何开启 JIT"
        case .stikDebug: return "使用 StikDebug 开启 JIT"
        default: return HuskBuiltInJIT.isAvailable ? "使用 StikJIT 开启 JIT" : "开启 JIT"
        }
    }

    private var on: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("JIT 已开启").font(.headline)
                Text("游戏与 Android 虚拟机随时可运行。").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .huskCard()
    }

    private var off: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: "bolt.fill").font(.title3).foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(offered == .builtIn ? "StikJIT" : offered.title).font(.title3.weight(.semibold))
                    Text("开启 JIT").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(explanation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if let why = HuskBuiltInJIT.unavailableReason {
                Text(why).font(.footnote).foregroundStyle(.orange)
            }

            if jit.busy {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(jit.status ?? "正在开启 JIT…").font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                Button {
                    // The one this card offers, whatever "Automatic" would have picked.
                    if offered == .builtIn, HuskBuiltInJIT.isAvailable { jit.method = .builtIn }
                    jit.enable()
                } label: {
                    HStack {
                        Spacer()
                        Label(buttonTitle, systemImage: "bolt.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let error = jit.error {
                Text(error).font(.footnote).foregroundStyle(.orange)
            }

            Button { jit.showSetup = true } label: {
                Text("首次使用？查看配置指引，或改用 StikDebug / TrollStore 开启")
                    .font(.footnote)
            }
        }
        .padding(16)
        .huskCard()
    }
}
