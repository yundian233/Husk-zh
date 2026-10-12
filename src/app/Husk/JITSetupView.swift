// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import UniformTypeIdentifiers

/// The JIT walkthrough: pick a way in, follow its numbered steps, end with JIT on.
///
/// Three ways in. Pairing on this iPhone (iOS 27) and a pairing file made on a
/// computer both lead to Built-in StikJIT and share the last two steps,
/// LocalDevVPN and enabling. StikDebug has its own short page. Presented from
/// onboarding, Settings › JIT, and whenever Start finds JIT not set up.
struct JITSetupFlow: View {
    enum Step: Hashable { case pairOnDevice, importFile, connect, enable, stikDebug, trollStore, jailbreak }

    @ObservedObject private var jit = JITCoordinator.shared
    @ObservedObject private var pairing = OnDevicePairing.shared
    @State private var path: [Step] = []
    @State private var importing = false
    @Environment(\.dismiss) private var dismiss

    private var device: String { OnDevicePairing.deviceKind }

    var body: some View {
        NavigationStack(path: $path) {
            choose
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .pairOnDevice: pairOnDevice
                    case .importFile: importFile
                    case .connect: connect
                    case .enable: enable
                    case .stikDebug: stikDebug
                    case .trollStore: trollStore
                    case .jailbreak: jailbreak
                    }
                }
        }
        .tint(Theme.accent)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.propertyList, .data]) { result in
            switch result {
            case .success(let url): jit.importPairingFile(url)
            case .failure(let failure):
                HuskLog.log("jit", "pairing import failed: \(failure.localizedDescription)")
            }
        }
        .onAppear {
            jit.refreshPairingStatus()
            pairing.reset()
            // A failed enable from the Library lands on the step that can fix it.
            if jit.error != nil, jit.hasPairing, jit.resolvedMethod == .builtIn {
                path = [.enable]
            }
            HuskLog.log("ui", "JIT walkthrough opened")
        }
        // Swiping the sheet away, or a copy shown from onboarding, must not
        // leave a request to show it again behind.
        .onDisappear { jit.showSetup = false }
    }

    private func close() {
        jit.showSetup = false
        dismiss()
    }

    // MARK: Choose

    private var choose: some View {
        page(symbol: "bolt.fill", title: "启用 JIT",
             subtitle: "Android 需要可写可执行内存权限，在 iOS 上仅能通过调试器授予。请选择适合你的方式。") {
            VStack(spacing: 10) {
                let builtIn = HuskBuiltInJIT.unavailableReason
                way("在此 \(device) 上直接配对", symbol: "iphone.radiowaves.left.and.right",
                    detail: builtIn ?? (!OnDevicePairing.isSupported ? "需要 iOS 27 或更高版本。"
                        : jit.pairingSource == .onDevice ? "已在此 \(device) 上配对。"
                        : "无需电脑，可在系统设置中 1 分钟内完成配对。"),
                    done: jit.pairingSource == .onDevice,
                    enabled: builtIn == nil && OnDevicePairing.isSupported) { path.append(.pairOnDevice) }
                way("使用配对文件", symbol: "doc.badge.plus",
                    detail: builtIn ?? (jit.pairingSource == .imported ? "已导入配对文件。"
                        : "导入电脑生成的配对文件。"),
                    done: jit.pairingSource == .imported,
                    enabled: builtIn == nil) { path.append(.importFile) }
                way("使用 StikDebug", symbol: "ant",
                    detail: JITBootstrap.isStikDebugInstalled ? "已安装 StikDebug。"
                        : "通过 StikDebug 应用启用 JIT。",
                    done: jit.method == .stikDebug) { path.append(.stikDebug) }
                way("使用 TrollStore", symbol: "sparkles",
                    detail: JITBootstrap.isTrollStoreInstalled ? "已安装 TrollStore。"
                        : "适用于通过 TrollStore 安装的 Husk。",
                    done: jit.method == .trollStore) { path.append(.trollStore) }
                way("使用越狱环境", symbol: "lock.open",
                    detail: JITBootstrap.debuggedAtLaunch ? "打开 Husk 时 JIT 已处于开启状态。"
                        : JITBootstrap.isJailbroken ? "已检测到越狱。请在越狱设置中开启应用 JIT 权限。"
                        : "Dopamine 越狱可一键为应用开启 JIT 权限。",
                    done: jit.method == .jailbreak || JITBootstrap.debuggedAtLaunch) { path.append(.jailbreak) }
            }
            if jit.hasPairing && HuskBuiltInJIT.isAvailable {
                Button { path.append(.connect) } label: {
                    Label("继续使用当前配对", systemImage: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.top, 4)
            }
        } actions: {
            Button("稍后再说") { close() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textDim)
        }
    }

    private func way(_ title: String, symbol: String, detail: String, done: Bool,
                     enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(detail).font(.system(size: 13)).foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: done ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: done ? 18 : 13, weight: .semibold))
                    .foregroundStyle(done ? .green : Theme.textDim.opacity(0.7))
            }
            .padding(14)
            .contentShape(Rectangle())
            .huskCard()
        }
        .buttonStyle(CardButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    // MARK: Pair on this device

    private var pairedOnDevice: Bool {
        if case .paired = pairing.phase { return true }
        return false
    }

    private var pairOnDevice: some View {
        page(symbol: "iphone.radiowaves.left.and.right", title: "在此 \(device) 上直接配对",
             subtitle: "Husk 会在你的 Wi-Fi 局域网中模拟为一台电脑，让你的 \(device) 像与 Mac 电脑配对一样完成互联。") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "打开 Wi-Fi，点击下方的 **开始配对** 并允许本地网络访问权限。",
                      done: pairing.phase != .idle)
                point(2, "打开 **系统设置 › 隐私与安全性 › 开发者模式**，向下滚动并点击 "
                       + "**与 \(OnDevicePairing.hostName) 配对**。",
                      done: pairing.isShowingPin || pairedOnDevice)
                point(3, "输入 Husk 显示的配对码。配对码同时会以通知横幅展示，无需反复切换应用。",
                      done: pairedOnDevice)
                point(4, "返回 Husk 应用。", done: pairedOnDevice)
            }
            .padding(16).huskCard()
            pairingStatus
        } actions: {
            switch pairing.phase {
            case .idle, .failed:
                Button { pairing.start() } label: {
                    Label("开始配对", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(PrimaryButtonStyle())
            case .waiting, .pin:
                Button("取消配对", role: .cancel) { pairing.cancel() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textDim)
            case .paired:
                Button("继续") { path.append(.connect) }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder private var pairingStatus: some View {
        switch pairing.phase {
        case .idle:
            EmptyView()
        case .waiting:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.accent)
                    Text("正在等待你的 \(device)…").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                Button("打开系统设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .font(.system(size: 14, weight: .semibold))
                if pairing.backgroundLimited {
                    Text("系统配对在后台仅能保持约 30 秒等待状态，请立即前往“设置”操作。")
                        .font(.system(size: 13)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).huskCard()
        case .pin(let pin):
            VStack(spacing: 8) {
                Text("在你的 \(device) 上输入此配对码").font(.system(size: 14))
                    .foregroundStyle(Theme.textDim)
                Text(pin).font(.system(size: 40, weight: .bold, design: .monospaced)).tracking(6)
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .accessibilityLabel("配对码 \(pin.map(String.init).joined(separator: " "))")
            }
            .frame(maxWidth: .infinity)
            .padding(18).huskCard(high: true)
        case .paired(let name):
            outcome("已与 \(name) 完成配对", ok: true)
        case .failed(let message):
            outcome(message, ok: false)
        }
    }

    // MARK: Import a pairing file

    private var importFile: some View {
        page(symbol: "doc.badge.plus", title: "使用配对文件",
             subtitle: "在电脑上生成的配对文件能以相同方式让 Husk 与此 \(device) 建立通信。") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "在电脑上参考 [StikDebug 配对文件指南](https://github.com/StikDebug/StikDebug-Guide/blob/main/pairing_file.md) 为当前 \(device) 生成配对文件。",
                      done: jit.pairingSource == .imported)
                point(2, "将其保存到“文件”应用，或通过“隔空投送 (AirDrop)”发送至此 \(device)。",
                      done: jit.pairingSource == .imported)
                point(3, "轻点 **选择配对文件** 并选中该文件。", done: jit.pairingSource == .imported)
            }
            .padding(16).huskCard()
            Label("配对文件仅保存在 Husk 文档目录中，且仅发送给 Husk 自带的辅助扩展组件。",
                  systemImage: "lock.fill")
                .font(.system(size: 13)).foregroundStyle(Theme.textDim)
            if let error = jit.error { outcome(error, ok: false) }
        } actions: {
            if jit.pairingSource == .imported {
                Button("继续") { path.append(.connect) }.buttonStyle(PrimaryButtonStyle())
                Button("选择其他文件") { importing = true }
                    .font(.system(size: 15, weight: .medium))
            } else {
                Button { importing = true } label: { Label("选择配对文件", systemImage: "folder") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    // MARK: LocalDevVPN

    private var connect: some View {
        page(symbol: "network.badge.shield.half.filled", title: "连接 LocalDevVPN",
             subtitle: "Husk 辅助扩展通过本地 VPN 与此 \(device) 的调试服务建立通信，任何数据均不会离开你的 \(device)。") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "从 App Store 安装 [LocalDevVPN](\(LocalDevVPN.appStore.absoluteString))。",
                      done: LocalDevVPN.isInstalled)
                point(2, "点击 **连接 LocalDevVPN**。开启 VPN 后即可立即返回 Husk。")
                point(3, "在开启 JIT 时保持其连接状态。")
            }
            .padding(16).huskCard()
        } actions: {
            Button(LocalDevVPN.actionTitle) { LocalDevVPN.open() }
                .buttonStyle(PrimaryButtonStyle())
            Button("已连接完成") { path.append(.enable) }
                .font(.system(size: 15, weight: .medium))
        }
    }

    // MARK: Enable

    private var attached: Bool { jit.attachGeneration > 0 || JITBootstrap.debuggedFlag }

    private var enable: some View {
        page(symbol: "bolt.badge.checkmark", title: "启用 JIT",
             subtitle: "首次运行检查将下载并挂载 Apple 开发者磁盘映像 (DDI)，通常耗时约 1 分钟。") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "点击 **检查配置**。Husk 将检查 LocalDevVPN 并准备开发者磁盘映像。",
                      done: jit.prepared || attached)
                point(2, "点击 **启用 JIT**。Husk 辅助服务将附加到进程，Android 即可启动。", done: attached)
            }
            .padding(16).huskCard()

            if jit.busy {
                HStack(spacing: 11) {
                    ProgressView().tint(Theme.accent)
                    Text(jit.status ?? "处理中…").font(.system(size: 14)).foregroundStyle(Theme.text)
                    Spacer(minLength: 0)
                }
                .padding(16).huskCard(high: true)
            } else if attached {
                outcome("JIT 已就绪，可随时启动 Android。", ok: true)
            } else if let error = jit.error {
                VStack(alignment: .leading, spacing: 10) {
                    outcome(error, ok: false)
                    if jit.connectionProblem == .pairing {
                        Button(OnDevicePairing.isSupported ? "重新配对" : "导入新配对文件") {
                            path = [OnDevicePairing.isSupported ? .pairOnDevice : .importFile]
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    if jit.connectionProblem != nil {
                        Button(LocalDevVPN.actionTitle) { LocalDevVPN.open() }
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            } else if let status = jit.status {
                outcome(status, ok: true)
            }

            if !attached {
                Button("重置开发者磁盘映像 (DDI)", role: .destructive) { jit.resetDDI() }
                    .font(.system(size: 13, weight: .medium))
                    .disabled(jit.busy)
                    .padding(.top, 4)
            }
        } actions: {
            if attached {
                Button("完成") { close() }.buttonStyle(PrimaryButtonStyle())
            } else if jit.prepared {
                Button { jit.enableBuiltIn() } label: { Label("启用 JIT", systemImage: "bolt.fill") }
                    .buttonStyle(PrimaryButtonStyle(enabled: !jit.busy))
                    .disabled(jit.busy)
            } else {
                Button("检查配置") { jit.prepareBuiltIn() }
                    .buttonStyle(PrimaryButtonStyle(enabled: !jit.busy))
                    .disabled(jit.busy)
            }
        }
    }

    // MARK: StikDebug

    private var stikDebug: some View {
        page(symbol: "ant", title: "使用 StikDebug",
             subtitle: "StikDebug 是一个独立的调试辅助 App。Husk 会直接向其传递 JIT 运行脚本，无需在 StikDebug 内部进行任何单独配置。") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "安装最新版 [StikDebug](https://github.com/StikDebug/StikDebug/releases/latest)。",
                      done: JITBootstrap.isStikDebugInstalled)
                point(2, "将此 \(device) 的配对文件导入 StikDebug。")
                point(3, "安装并连接 [LocalDevVPN](\(LocalDevVPN.appStore.absoluteString))。")
                point(4, "每当启动 Android 时，Husk 会调起 StikDebug 附加并在完成后自动返回。")
            }
            .padding(16).huskCard()
        } actions: {
            Button("使用 StikDebug") {
                jit.method = .stikDebug
                HuskLog.log("ui", "JIT method set to StikDebug")
                close()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: TrollStore

    private var trollStore: some View {
        page(symbol: "sparkles", title: "使用 TrollStore",
             subtitle: "TrollStore 可直接免配对文件、免 VPN、免电脑为其安装的应用开启 JIT 权限。") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "在支持 TrollStore 的系统上通过 TrollStore 安装 Husk.ipa。该安装包保留了 TrollStore 权限，在侧载器中同样适用。",
                      done: JITBootstrap.isInstalledWithTrollStore)
                point(2, "在 TrollStore 的“设置”中，务必开启“URL Scheme”。若未开启，TrollStore 将忽略 JIT 激活请求。",
                      done: JITBootstrap.isTrollStoreInstalled)
                point(3, "每当启动 Android 或游戏时，Husk 会请求 TrollStore 开启 JIT。TrollStore 将调起 Husk 短暂附加后分离，此时进程已获得执行内存权限。")
            }
            .padding(16).huskCard()
            if !JITBootstrap.isTrollStoreInstalled {
                Label("在此 \(device) 上未检测到 TrollStore。只有安装了 TrollStore 并且 Husk 是通过其安装时方可使用。", systemImage: "info.circle")
                    .font(.system(size: 13)).foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            Button("使用 TrollStore") {
                jit.method = .trollStore
                HuskLog.log("ui", "JIT method set to TrollStore")
                close()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: Jailbreak

    private var jailbreak: some View {
        page(symbol: "lock.open", title: "使用越狱环境",
             subtitle: "在使用 Dopamine 等工具越狱的设备上，JIT 仅是一个开关：越狱会在应用启动时自动标记为已调试，已调试应用可自由执行 JIT 代码。无需任何额外配置。") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "打开 Dopamine 并进入“设置”。", done: JITBootstrap.isJailbroken)
                point(2, "开启“允许应用 JIT”开关。")
                point(3, "彻底退出 Husk 并重新打开。该设置会在应用启动时自动生效。",
                      done: JITBootstrap.debuggedAtLaunch)
            }
            .padding(16).huskCard()
            if JITBootstrap.debuggedAtLaunch {
                Label("Husk 在启动时已由越狱环境附加调试标记，JIT 已开启。", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13)).foregroundStyle(.green)
            } else if !JITBootstrap.isJailbroken {
                Label("在此 \(device) 上未检测到越狱环境。", systemImage: "info.circle")
                    .font(.system(size: 13)).foregroundStyle(Theme.textDim)
            }
        } actions: {
            Button("使用越狱模式") {
                jit.method = .jailbreak
                HuskLog.log("ui", "JIT method set to jailbreak")
                close()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: Pieces

    private func page<Content: View, Actions: View>(
        symbol: String, title: String, subtitle: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions) -> some View {
        ZStack {
            Theme.backdrop
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 56, height: 56)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text(title).font(.system(size: 28, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(subtitle).font(.system(size: 15)).foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    content()
                }
                .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) { actions() }
                .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 16)
                .background(Theme.backdrop)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("关闭") { close() }
            }
        }
    }

    private func point(_ number: Int, _ text: String, done: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green.opacity(0.18) : Theme.accentSoft)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.green)
                } else {
                    Text("\(number)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accent)
                }
            }
            .frame(width: 26, height: 26)
            Text(.init(text))
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func outcome(_ text: String, ok: Bool) -> some View {
        Label(text, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(ok ? .green : .red)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).huskCard()
    }
}
