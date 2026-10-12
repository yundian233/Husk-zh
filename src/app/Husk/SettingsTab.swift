// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

/// Settings, as the iOS Settings app lays them out: a card for the app up top, then groups of rows that each
/// push a page of their own. What belongs to the app, what belongs to the emulator, and what the thing is.
struct SettingsTab: View {
    @AppStorage(AppWindows.defaultKey) private var multitask = false
    @AppStorage(CompatibilityStore.askKey) private var askCompat = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { AboutSettings() } label: { appCard }
                }

                Section {
                    row(JITSettings(), "bolt.fill", .yellow, "JIT 与侧载", "内置 StikJIT — 推荐使用方式")
                } header: {
                    Text("JIT")
                } footer: {
                    Text("Android 和转译层游戏需要 JIT。Husk 内置的 StikJIT 可免电脑直接开启。")
                }

                Section("通用") {
                    row(DiscoverView(), "sparkle.magnifyingglass", .mint, "发现", "在 F-Droid 和其他软件源中查找应用")
                    row(LibrarySettings(), "square.grid.2x2.fill", .blue, "应用库", "管理应用及其图标")
                    row(PerformanceSettings(), "speedometer", .orange, "性能", "渲染器、音频")
                    row(AppearanceSettings(), "paintbrush.fill", .pink, "外观", "明暗模式、强调色、应用图标")
                }

                Section {
                    Toggle(isOn: $multitask) {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("在窗口中打开应用")
                                Text("在应用运行时继续使用 Husk").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        } icon: {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.purple.gradient)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: "macwindow.on.rectangle")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                        }
                    }
                } header: {
                    Text("多任务窗口")
                } footer: {
                    Text("应用和游戏将在悬浮窗口中打开，支持移动、缩放和最小化到底部坞栏，类似 LiveContainer 的多任务模式。每个应用也可在自身设置中单独覆盖此选项。")
                }

                Section {
                    Toggle(isOn: $askCompat) {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("询问游戏运行体验")
                                Text("游戏结束后询问一次（每次版本更新仅一次）").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        } icon: {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.green.gradient)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: "list.bullet.clipboard")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                        }
                    }
                    Link(destination: CompatibilityStore.site) {
                        Label("兼容性列表", systemImage: "safari")
                    }
                } header: {
                    Text("兼容性")
                } footer: {
                    Text("游戏详情页和商店会展示来自 antiweb.lol 的兼容性数据。你的评估报告将附带设备型号、iOS 版本、Husk 构建号及 JIT 方式上传供社区参考。")
                }

                Section("模拟器") {
                    row(InputSettings(), "hand.tap.fill", .indigo, "输入", "屏幕、触控、键盘")
                    row(NetworkSettings(), "globe", .green, "网络", "互联网与会话保存")
                    row(SavedMachineSettings(), "externaldrive.fill", .teal, "已保存虚拟机", "快照与自动保存")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
        }
    }

    private var appCard: some View {
        HStack(spacing: 14) {
            HuskMark(size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("Husk").font(.title3.weight(.semibold))
                Text("版本 \(Bundle.main.version) · \(Bundle.main.commit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func row<D: View>(_ destination: D, _ icon: String, _ tint: Color,
                              _ title: String, _ subtitle: String) -> some View {
        NavigationLink { destination } label: {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            } icon: {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.gradient)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                    }
            }
        }
    }
}

/// A Form, as the system draws one.
private struct HuskForm: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    func huskForm() -> some View { modifier(HuskForm()) }
}

// MARK: - Library

struct LibrarySettings: View {
    @ObservedObject private var host = AndroidHost.shared
    @State private var working = false

    var body: some View {
        Form {
            Section {
                DetailRow(label: "应用总数", value: "\(host.packages.count)", mono: false)
                DetailRow(label: "包含图标",
                          value: "\(host.packages.filter { $0.iconPath != nil }.count)",
                          mono: false)
            } footer: {
                Text("列表已保存在本地磁盘中，在 Android 完成启动前即可浏览。")
            }

            Section {
                Button {
                    working = true
                    Task { await host.refreshPackages(); working = false }
                } label: {
                    Label(working ? "正在刷新…" : "从 Android 刷新",
                          systemImage: "arrow.clockwise")
                }
                .disabled(working || !host.isReady)

                Button {
                    AndroidHost.forgetIcons()
                    working = true
                    Task { await host.refreshPackages(); working = false }
                } label: {
                    Label("重新获取图标", systemImage: "photo.on.rectangle")
                }
                .disabled(working || !host.isReady)
            } footer: {
                Text("名称和图标均取自 Android 自身的启动器。重新获取将清除本地缓存并重新提取。")
            }
        }
        .huskForm()
        .navigationTitle("应用库")
    }
}

// MARK: - Performance

struct PerformanceSettings: View {
    @ObservedObject private var runner = QemuRunner.shared
    @State private var gpuMode =
        UserDefaults.standard.object(forKey: "husk.gpuMode") as? Bool ?? true
    @State private var sound = UserDefaults.standard.bool(forKey: "husk.sound")
    @State private var soundDevice =
        UserDefaults.standard.object(forKey: "husk.soundDevice") as? Bool ?? true

    var body: some View {
        Form {
            Section {
                Picker("渲染器", selection: $gpuMode) {
                    Text("GPU").tag(true)
                    Text("CPU").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: gpuMode) { v in
                    UserDefaults.standard.set(v, forKey: "husk.gpuMode")
                    HuskLog.log("ui", v ? "GPU renderer selected" : "CPU renderer selected")
                }
            } header: {
                Text("渲染器")
            } footer: {
                Text(gpuMode
                     ? "Android 通过 Metal 在真实 GPU 上进行渲染 — 帧率约为 CPU 的四倍。推荐使用此默认模式。"
                     : "所有画面均由模拟 CPU 逐像素绘制。速度慢得多，仅在 GPU 渲染异常时建议使用。")
            }

            Section {
                DetailRow(label: "帧率",
                          value: runner.fps > 0
                                 ? String(format: "%.0f fps", runner.fps) : "—")
                DetailRow(label: "虚拟机分辨率",
                          value: "\(QemuRunner.lastGuestRes.w)×\(QemuRunner.lastGuestRes.h)")
            } header: {
                Text("当前状态")
            }

            Section {
                Toggle("音频", isOn: $sound)
                    .onChange(of: sound) { v in
                        UserDefaults.standard.set(v, forKey: "husk.sound")
                        HuskLog.log("ui", v ? "sound on" : "sound off")
                    }
                if sound {
                    Toggle("挂载虚拟声卡", isOn: $soundDevice)
                        .onChange(of: soundDevice) { v in
                            UserDefaults.standard.set(v, forKey: "husk.soundDevice")
                        }
                }
            } header: {
                Text("音频")
            } footer: {
                Text("添加虚拟声卡设备。挂载声卡时无法保存状态快照（QEMU 会拒绝为此状态建立快照），因此每次启动都将冷启动。开启或关闭此项都需要一次冷启动。")
            }
        }
        .huskForm()
        .navigationTitle("性能")
    }
}

// MARK: - Input

struct InputSettings: View {
    @State private var landscapeGuest =
        UserDefaults.standard.bool(forKey: "husk.landscapeGuest")
    @State private var customRes = UserDefaults.standard.bool(forKey: "husk.customRes")
    @State private var widthText = InputSettings.stored("husk.resWidth", 720)
    @State private var heightText = InputSettings.stored("husk.resHeight", 1280)

    /// Sizes worth offering without typing. Deliberately short: these are the
    /// shapes a phone guest is actually run at, not a catalogue of every panel
    /// ever made.
    private static let presets: [(name: String, w: Int, h: Int)] = [
        ("小型 — 360 × 800", 360, 800),
        ("高清 — 720 × 1280", 720, 1280),
        ("全高清 — 1080 × 1920", 1080, 1920),
        ("横屏高清 — 1280 × 720", 1280, 720),
        ("平板 — 1280 × 800", 1280, 800),
    ]

    private static func stored(_ key: String, _ fallback: Int) -> String {
        let v = UserDefaults.standard.integer(forKey: key)
        return String(v > 0 ? v : fallback)
    }

    /// What the typed numbers actually come to, or nothing if they are not a
    /// size the guest can be given.
    private var effective: (w: Int, h: Int)? {
        QemuRunner.validResolution(w: Int(widthText) ?? 0, h: Int(heightText) ?? 0)
    }

    var body: some View {
        Form {
            Section {
                Picker("屏幕方向", selection: $landscapeGuest) {
                    Text("竖屏").tag(false)
                    Text("横屏").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(customRes)
                .onChange(of: landscapeGuest) { v in
                    UserDefaults.standard.set(v, forKey: "husk.landscapeGuest")
                    HuskLog.log("ui", v ? "guest panel will be landscape"
                                        : "guest panel will be portrait")
                }
            } header: {
                Text("屏幕方向")
            } footer: {
                Text(customRes
                     ? "自定义分辨率已直接指定屏幕规格，因此在此模式下屏幕方向切换不生效。如需横屏请在下方输入较宽的尺寸。"
                     : "Android 运行后无法动态调整屏幕比例，因此在竖屏下运行横屏游戏会缩放在黑边条内显得极小。直接以横屏启动才能填满屏幕，此时竖屏应用将居中显示。修改需要一次冷启动。")
            }

            Section {
                Toggle("自定义分辨率", isOn: $customRes)
                    .onChange(of: customRes) { v in
                        UserDefaults.standard.set(v, forKey: "husk.customRes")
                        store()
                        HuskLog.log("ui", v ? "custom resolution on: "
                                            + "\(widthText)x\(heightText)"
                                            : "custom resolution off")
                    }

                if customRes {
                    Picker("预设尺寸", selection: Binding(
                        get: { presetIndex },
                        set: { i in
                            guard i >= 0, i < Self.presets.count else { return }
                            widthText = String(Self.presets[i].w)
                            heightText = String(Self.presets[i].h)
                            store()
                        })) {
                        ForEach(0..<Self.presets.count, id: \.self) { i in
                            Text(Self.presets[i].name).tag(i)
                        }
                        Text("自定义").tag(-1)
                    }

                    HStack {
                        Text("宽度")
                        Spacer()
                        TextField("720", text: $widthText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.technical())
                            .frame(width: 90)
                            .onChange(of: widthText) { _ in store() }
                    }
                    HStack {
                        Text("高度")
                        Spacer()
                        TextField("1280", text: $heightText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.technical())
                            .frame(width: 90)
                            .onChange(of: heightText) { _ in store() }
                    }

                    if let size = effective {
                        DetailRow(label: "Android 实际分辨率",
                                  value: "\(size.w) × \(size.h)")
                    } else {
                        Text("长宽尺寸必须在 240 到 2560 之间。")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                DetailRow(label: "当前运行分辨率", value: running)
            } header: {
                Text("分辨率")
            } footer: {
                Text("屏幕规格在虚拟机启动时构建，修改后需要一次冷启动生效，并且下次保存时会覆盖旧尺寸的快照。分辨率数值将自动舍入为 8 的倍数。尺寸越大渲染负担越重。Android 的显示密度不会随分辨率改变，因此分辨率越高显示的内容越多。")
            }

            Section {
                Text("触控已默认开启。键盘与旋转控制位于虚拟机屏幕底部的操作栏中；手柄与鼠标指针映射正在开发中。")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("控制与输入")
            }
        }
        .huskForm()
        .navigationTitle("输入")
    }

    /// The panel the guest actually has, which only means anything while there
    /// is a guest: the stored value is last launch's until one starts.
    private var running: String {
        guard QemuRunner.shared.isRunning else { return "未启动" }
        return "\(QemuRunner.lastGuestRes.w) × \(QemuRunner.lastGuestRes.h)"
    }

    /// Which preset the typed numbers are, if any.
    private var presetIndex: Int {
        guard let size = effective else { return -1 }
        return Self.presets.firstIndex { $0.w == size.w && $0.h == size.h } ?? -1
    }

    private func store() {
        UserDefaults.standard.set(Int(widthText) ?? 0, forKey: "husk.resWidth")
        UserDefaults.standard.set(Int(heightText) ?? 0, forKey: "husk.resHeight")
    }
}

// MARK: - Network

struct NetworkSettings: View {
    @State private var keepNetwork =
        UserDefaults.standard.object(forKey: "husk.keepNetwork") as? Bool ?? true

    var body: some View {
        Form {
            Section {
                Toggle("保存快照时保留网络连接", isOn: $keepNetwork)
                    .onChange(of: keepNetwork) { v in
                        UserDefaults.standard.set(v, forKey: "husk.keepNetwork")
                    }
            } footer: {
                Text(keepNetwork
                     ? "保存快照时将关闭所有前台应用，但保留 Android 系统框架运行，以便在恢复快照后网络仍可立即使用。"
                     : "保存快照时同时停止系统框架，并清理所有 GPU 资源，运行更稳定 — 但网络可能需要冷启动后才能恢复。")
            }

            Section {
                Text("Android 通过 QEMU 内部虚拟网卡访问互联网。本地局域网无法探测虚拟机，虚拟机也无法探测局域网。")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("网络连接说明")
            }
        }
        .huskForm()
        .navigationTitle("网络")
    }
}

// MARK: - JIT and sideloading

struct JITSettings: View {
    @ObservedObject private var runner = QemuRunner.shared
    @ObservedObject private var jit = JITCoordinator.shared
    @State private var autoStart = Onboarding.autoStart
    @AppStorage(JITCoordinator.autoEnableKey) private var autoJIT = false
    @State private var keepAttached = JITBootstrap.keepDebuggerAttached

    private var pairingLabel: String {
        switch jit.pairingSource {
        case .onDevice: return "本机已配对"
        case .imported: return "已导入配对文件"
        case nil: return "未配置"
        }
    }

    var body: some View {
        Form {
            Section {
                JITCard()
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                Picker("激活方式", selection: $jit.method) {
                    ForEach(JITMethod.allCases) { Text($0.title).tag($0) }
                }
                DetailRow(label: "StikDebug",
                          value: JITBootstrap.isStikDebugInstalled ? "已安装" : "未找到", mono: false)
                DetailRow(label: "TrollStore",
                          value: JITBootstrap.isTrollStoreInstalled ? "已安装" : "未找到", mono: false)
                DetailRow(label: "由 TrollStore 安装",
                          value: JITBootstrap.isInstalledWithTrollStore ? "是" : "否", mono: false)
                DetailRow(label: "越狱环境",
                          value: JITBootstrap.debuggedAtLaunch ? "已允许应用 JIT"
                               : JITBootstrap.isJailbroken ? "已检测到" : "未检测到", mono: false)
                DetailRow(label: "内置配对", value: pairingLabel, mono: false)
                Button {
                    jit.showSetup = true
                } label: {
                    Label("配置 JIT", systemImage: "wand.and.stars")
                }
            } header: {
                Text("JIT 激活方式")
            } footer: {
                Text(jit.method == .automatic
                     ? jit.automaticDescription + " 内置 StikJIT 需要 iOS 17+、LocalDevVPN 以及配对文件（iOS 17+ 上 Husk 可自动生成）。"
                     : HuskBuiltInJIT.unavailableReason ?? "内置 StikJIT 需要 LocalDevVPN 与配对文件（iOS 17+ 上 Husk 可自动生成）。")
            }

            Section {
                DetailRow(label: "调试器状态",
                          value: JITBootstrap.isDebuggerAttached ? "已附加" : "未附加",
                          mono: false)
                DetailRow(label: "可执行内存权限",
                          value: JITBootstrap.isLive ? "已授予" : "未获取", mono: false)
                // The two routes, named separately. Either one is enough, and
                // when someone reports "JIT does not work" these two rows are
                // the whole diagnosis.
                DetailRow(label: "陷阱指令处理",
                          value: husk_ios_jit_self_route() != nil ? "无需使用"
                               : JITBootstrap.prewarmed ? "正常响应" : "无响应",
                          mono: false)
                if let route = husk_ios_jit_self_route() {
                    DetailRow(label: "分配方式",
                              value: String(cString: route) == "MAP_JIT" ? "MAP_JIT (TrollStore 签名权限)" : "普通内存 (调试器或越狱环境)",
                              mono: false)
                }
                // Cached answer only: running the probe from a view body
                // could freeze the app (see JITBootstrap.mapJITWorks).
                DetailRow(label: "MAP_JIT",
                          value: JITBootstrap.deviceEnforcesTXM ? "未启用 (TXM 限制)"
                               : JITBootstrap.mapJITResult.map { $0 ? "可执行" : "被拒绝" }
                                 ?? "未测试",
                          mono: false)
                DetailRow(label: "配置后调试器",
                          value: JITBootstrap.detached ? "已分离" : "已附加",
                          mono: false)
                if let why = JITBootstrap.lastFailure {
                    Text(why).font(.caption).foregroundStyle(.orange)
                }
                if !JITBootstrap.ready {
                    Button {
                        jit.enable()
                    } label: {
                        Label("使用 \(jit.resolvedMethod.title) 开启 JIT", systemImage: "bolt.fill")
                    }
                    .disabled(jit.busy)
                    Button {
                        _ = JITBootstrap.requestTrollStoreAttach()
                    } label: {
                        Label("使用 TrollStore 开启 JIT", systemImage: "sparkles")
                    }
                }
            } header: {
                Text("JIT")
            } footer: {
                Text("Husk 需要先写后执行的内存权限，在 iOS 上通常需要附加调试器。获取方式主要有两种：处理陷阱指令的调试器，或内核为调试进程提供的 MAP_JIT 映射。二者满足其一即可 — 具体取决于设备型号与 iOS 系统版本，因此 Husk 会逐一进行测试。")
            }

            Section {
                Toggle("启动时自动开启 JIT", isOn: $autoJIT)
                    .disabled(!HuskBuiltInJIT.isAvailable)
            } footer: {
                Text(HuskBuiltInJIT.isAvailable
                     ? "每次打开 Husk 检测到未开启 JIT 时，会自动调用内置 StikJIT 开启，无需手动操作。需要先完成一次配对配置。"
                     : "需要内置 StikJIT 支持（适用于 iOS 16 及更高版本）。")
            }

            Section {
                Toggle("启动时自动运行 Android", isOn: $autoStart)
                    .onChange(of: autoStart) { v in
                        UserDefaults.standard.set(v, forKey: "husk.autoStart")
                    }
            } footer: {
                Text("在检测到 JIT 可用时，打开 Husk 即自动启动虚拟机系统。")
            }

            Section {
                Toggle("保持调试器附加", isOn: $keepAttached)
                    .onChange(of: keepAttached) { v in JITBootstrap.keepDebuggerAttached = v }
            } footer: {
                Text("默认关闭。在锁定 JIT 内存区域后 Husk 会立即分离 StikDebug，因为被 iOS 挂起的调试器在下次唤醒时可能导致整个应用卡死。仅在需要收集 StikDebug 自身日志时开启此项。")
            }

            Section {
                Text("可通过媒体库右上角“+”按钮或“文件”标签页安装 APK。对于拆分安装包（base APK 加上 config 拆分包），必须同时勾选导入；若只安装 base 包会因缺少原生库而启动失败。")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("侧载安装")
            }
        }
        .huskForm()
        .navigationTitle("JIT 与侧载")
    }
}

// MARK: - Saved machine

struct SavedMachineSettings: View {
    @ObservedObject private var runner = QemuRunner.shared
    @State private var autoSave =
        UserDefaults.standard.object(forKey: "husk.autoSave") as? Bool ?? true
    @State private var useSnapshot =
        UserDefaults.standard.object(forKey: "husk.downloadSnapshot") as? Bool ?? true
    @State private var askWhichToDelete = false
    @State private var deleteResult: String?
    @AppStorage(GuestImage.askUpdatesKey) private var askUpdates = true

    var body: some View {
        Form {
            Section {
                Toggle("自动保存虚拟机", isOn: $autoSave)
                    .onChange(of: autoSave) { v in
                        UserDefaults.standard.set(v, forKey: "husk.autoSave")
                        HuskLog.log("ui", v ? "automatic saving on" : "automatic saving off")
                    }
                Button {
                    QemuRunner.shared.saveState(reason: "asked from settings")
                } label: {
                    Label(runner.isSavingState ? "正在保存…" : "立即保存",
                          systemImage: "externaldrive.badge.checkmark")
                }
                .disabled(runner.isSavingState)
            } footer: {
                Text("Husk 优先从快照直接恢复虚拟机，耗时仅需数秒而非数分钟。写入快照期间画面会暂时冻结。关闭此项后不会自动保存快照（包括安装应用之后）。")
            }

            Section {
                Button(role: .destructive) { askWhichToDelete = true } label: {
                    Label("删除已保存虚拟机", systemImage: "trash")
                }
                .disabled(!QemuRunner.shared.hasSnapshot)
                if let deleteResult {
                    Text(deleteResult).font(.caption).foregroundStyle(.secondary)
                }
            } footer: {
                Text(QemuRunner.shared.hasSnapshot
                     ? "当前已保存快照：" + ((QemuRunner.shared.snapshotDisplay ?? "sw").contains("gl") ? "GPU 模式" : "软件渲染模式") + "。"
                     : "未保存快照，Android 将冷启动。")
            }

            Section {
                Toggle("下载预启动快照", isOn: $useSnapshot)
                    .onChange(of: useSnapshot) { v in
                        UserDefaults.standard.set(v, forKey: "husk.downloadSnapshot")
                    }
            } footer: {
                Text("首次下载时额外增加约 2 GB。该快照在软件渲染器下制作，因此 GPU 模式下不适用 — GPU 模式将在首次冷启动后自行保存专属快照。")
            }

            Section {
                Toggle("提示系统镜像更新", isOn: $askUpdates)
            } footer: {
                Text("当官方发布新版本 Android 系统镜像或快照时，Husk 会询问是否下载。未下载过 Android 时不会提示。")
            }
        }
        .huskForm()
        .navigationTitle("已保存虚拟机")
        .confirmationDialog("请选择要删除的已保存虚拟机", isPresented: $askWhichToDelete,
                            titleVisibility: .visible) {
            Button("GPU 虚拟机快照", role: .destructive) { forget("gl", "GPU") }
            Button("软件渲染虚拟机快照", role: .destructive) { forget("sw", "软件渲染") }
            Button("取消", role: .cancel) { }
        } message: {
            Text("Android 下次将进行完整冷启动，并在启动后保存新快照。")
        }
    }

    private func forget(_ mode: String, _ name: String) {
        if QemuRunner.shared.forgetSnapshot(mode: mode) {
            deleteResult = "已删除 \(name) 虚拟机。下次启动将执行冷启动。"
        } else {
            deleteResult = "未保存 \(name) 虚拟机，无需删除。"
        }
    }
}

// MARK: - Appearance

struct AppearanceSettings: View {
    @State private var appIcon = HuskAppIcon.current
    @AppStorage(Theme.Appearance.key) private var appearance = Theme.Appearance.system
    @AppStorage(Holiday.key) private var holiday = true
    @ObservedObject private var theme = AppTheme.shared
    @Environment(\.colorScheme) private var scheme
    @State private var custom: Color = AppTheme.shared.accentColor

    private let iconColumns = [GridItem(.adaptive(minimum: 92), spacing: 14)]

    var body: some View {
        Form {
            Section {
                Picker("外观", selection: $appearance) {
                    ForEach(Theme.Appearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: appearance) { v in
                    HuskLog.log("ui", "appearance: \(v.rawValue)")
                }
                Toggle("节日下雪特效", isOn: $holiday)
            } header: {
                Text("主题")
            } footer: {
                Text("“跟随系统”将根据系统设置自动切换浅色或深色模式。无论哪种模式，虚拟机本身的屏幕画面均保持原有显示。")
            }

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                    ForEach(AppTheme.presets) { preset in
                        Button {
                            theme.accentColor = preset.color
                            custom = preset.color
                        } label: {
                            swatch(preset.color, selected: preset.color.themeHex == theme.accentColor.themeHex)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(preset.name)
                    }
                }
                .padding(.vertical, 6)

                ColorPicker("自定义强调色", selection: $custom, supportsOpacity: false)
                    .onChange(of: custom) { theme.accentColor = $0 }
            } header: {
                Text("强调主题色")
            } footer: {
                Text("调整整个应用内的按钮、开关及选中项的高亮颜色。")
            }

            Section {
                LazyVGrid(columns: iconColumns, spacing: 14) {
                    ForEach(HuskAppIcon.allCases) { icon in
                        Button {
                            appIcon = icon
                            HuskAppIcon.apply(icon)
                        } label: {
                            VStack(spacing: 8) {
                                if let art = icon.preview(dark: scheme == .dark) {
                                    Image(uiImage: art)
                                        .resizable().scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(appIcon == icon ? Color.accentColor : .clear, lineWidth: 3))
                                }
                                Text(icon.title)
                                    .font(.caption)
                                    .foregroundStyle(appIcon == icon ? Color.accentColor : .primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("应用图标")
            } footer: {
                Text("“自动”将跟随系统外观（浅色、深色或着色）。其他选项将固定显示指定图标。iOS 系统在更换图标后会弹出系统确认对话框（无法跳过）。")
            }
        }
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func swatch(_ color: Color, selected: Bool) -> some View {
        Circle()
            .fill(color)
            .frame(width: 34, height: 34)
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.9), lineWidth: selected ? 2 : 0).padding(-4))
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(color.isLight ? .black : .white)
                }
            }
            .frame(maxWidth: .infinity)
    }
}

// MARK: - About

struct AboutSettings: View {
    @ObservedObject private var runner = QemuRunner.shared
    @State private var showLogs = false
    @AppStorage(TranslationLayer.devInfoKey) private var devInfo = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    HuskMark(size: 84)
                    Text("Husk").font(.title2.weight(.semibold))
                    Text("版本 \(Bundle.main.version)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("构建版本", value: Bundle.main.commit)
                LabeledContent("系统镜像", value: GuestImage.imageVersion)
                LabeledContent("渲染器",
                               value: runner.displayKind == .gl ? "GPU"
                                    : runner.displayKind == .software ? "CPU"
                                    : "未启动")
            }

            Section {
                Toggle(isOn: $devInfo) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("开发者信息")
                        Text("在 Android 转译层界面中显示技术细节：库分析报告、设备检查与运行日志。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if devInfo {
                    NavigationLink { TLChecksView() } label: {
                        Label("设备检查", systemImage: "stethoscope")
                    }
                    NavigationLink { MassTestView() } label: {
                        Label("批量测试", systemImage: "square.stack.3d.down.forward")
                    }
                }
                Button { showLogs = true } label: {
                    Label("打开控制台", systemImage: "terminal")
                }
            } footer: {
                Text("Husk 在你的 iPhone 上通过真实 Android 环境运行未修改的原生 APK。控制台展示 Husk 实时日志、客户机串口输出以及 QEMU 诊断输出。")
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogs) { LogView() }
    }
}

extension Bundle {
    var version: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
    var commit: String {
        (infoDictionary?["HuskBuildCommit"] as? String) ?? "?"
    }
}
