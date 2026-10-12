// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import UIKit

/// What a person can change about how one game runs here, kept in the game's own folder (`settings.json`) so it goes when the game
/// does. Like LiveContainer's per-app settings: each game has its own, and nothing here touches another game.
struct TLAppSettings: Codable, Equatable {
    /// Which way up the screen is while the game runs.
    enum Orientation: String, Codable, CaseIterable, Identifiable {
        /// What the game asks for (its manifest), landscape when it does not say.
        case auto, landscape, portrait
        var id: String { rawValue }
        var title: String {
            switch self {
            case .auto: return "自动"
            case .landscape: return "横屏"
            case .portrait: return "竖屏"
            }
        }
    }

    /// How many pixels the game draws for each point of the screen. Fewer pixels run faster and take less memory.
    enum Resolution: String, Codable, CaseIterable, Identifiable {
        case low, medium, high, native
        var id: String { rawValue }
        var title: String {
            switch self {
            case .low: return "较低"
            case .medium: return "中等"
            case .high: return "较高"
            case .native: return "原生物理分辨率"
            }
        }
        var detail: String {
            switch self {
            case .low: return "1 倍分辨率渲染，速度最快。"
            case .medium: return "1.5 倍分辨率渲染。"
            case .high: return "2 倍分辨率渲染（默认推荐）。"
            case .native: return "物理全像素满分辨率渲染，最清晰但负载较高。"
            }
        }
        @MainActor var scale: CGFloat {
            switch self {
            case .low: return 1
            case .medium: return 1.5
            case .high: return 2
            case .native: return UIScreen.main.scale
            }
        }
    }

    /// When the on-screen controller is offered.
    enum PadMode: String, Codable, CaseIterable, Identifiable {
        /// For the games that cannot be played without a controller (Unreal, PC games through DXVK), when none is connected.
        case auto, always, never
        var id: String { rawValue }
        var title: String {
            switch self {
            case .auto: return "自动"
            case .always: return "始终开启"
            case .never: return "关闭"
            }
        }
    }

    /// Where the app opens: full screen, or a window over Husk that can be moved, resized and minimised (Multitasking).
    enum WindowMode: String, Codable, CaseIterable, Identifiable {
        /// As Settings › Multitasking says for every app.
        case auto, window, fullScreen
        var id: String { rawValue }
        var title: String {
            switch self {
            case .auto: return "默认"
            case .window: return "浮动窗口"
            case .fullScreen: return "全屏模式"
            }
        }
    }

    var orientation: Orientation = .auto
    var window: WindowMode = .auto
    var resolution: Resolution = .high
    /// The frames-per-second readout in the top bar.
    var showStats = true
    /// Start with nothing over the picture: no bar, no controller, no readout. Three fingers tapped together bring them back.
    var cleanView = false
    /// Stop the screen from dimming and locking while the game is on.
    var keepAwake = true
    var pad: PadMode = .auto
    /// Whether the controller is showing right now (the Pad button in the top bar toggles it).
    var padShown = true
    var padOpacity = 1.0
    var haptics = true
    /// Geometry Dash only: load Geode, its mod loader (Geode.swift).
    var geode = false

    init() {}

    // Settings written by an older Husk lack the keys a newer one added; each falls back to its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        orientation = try c.decodeIfPresent(Orientation.self, forKey: .orientation) ?? .auto
        resolution = try c.decodeIfPresent(Resolution.self, forKey: .resolution) ?? .high
        showStats = try c.decodeIfPresent(Bool.self, forKey: .showStats) ?? true
        cleanView = try c.decodeIfPresent(Bool.self, forKey: .cleanView) ?? false
        keepAwake = try c.decodeIfPresent(Bool.self, forKey: .keepAwake) ?? true
        pad = try c.decodeIfPresent(PadMode.self, forKey: .pad) ?? .auto
        padShown = try c.decodeIfPresent(Bool.self, forKey: .padShown) ?? true
        padOpacity = try c.decodeIfPresent(Double.self, forKey: .padOpacity) ?? 1.0
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        geode = try c.decodeIfPresent(Bool.self, forKey: .geode) ?? false
        window = try c.decodeIfPresent(WindowMode.self, forKey: .window) ?? .auto
    }

    private static func url(_ id: String) -> URL {
        TranslationLayer.root.appendingPathComponent(id, isDirectory: true).appendingPathComponent("settings.json")
    }

    static func load(_ id: String) -> TLAppSettings {
        (try? Data(contentsOf: url(id))).flatMap { try? JSONDecoder().decode(TLAppSettings.self, from: $0) } ?? TLAppSettings()
    }

    func save(_ id: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // The folder is gone when the app was removed while its settings page was open.
        guard FileManager.default.fileExists(atPath: Self.url(id).deletingLastPathComponent().path),
              let data = try? encoder.encode(self) else { return }
        try? data.write(to: Self.url(id), options: .atomic)
    }
}

// MARK: - The settings page

/// One game's settings, opened from its page or from its tile's menu.
struct TLAppSettingsView: View {
    let app: TLApp

    @ObservedObject private var store = TranslationLayerStore.shared
    @ObservedObject private var geode = GeodeSupport.shared
    @State private var settings: TLAppSettings
    @State private var name: String
    @State private var dataSize: String = "…"
    @State private var confirmReset = false
    @FocusState private var nameFocused: Bool

    init(app: TLApp) {
        self.app = app
        _settings = State(initialValue: TLAppSettings.load(app.id))
        _name = State(initialValue: app.label)
    }

    /// The game is loaded in this run of Husk, so what it keeps cannot be swapped from under it.
    private var inUse: Bool {
        guard let loaded = husk_native_loaded_apk().map({ String(cString: $0) }), let apk = app.apks.first else { return false }
        return loaded == apk
    }

    private var dataDirs: [URL] {
        let dir = TranslationLayer.root.appendingPathComponent(app.id, isDirectory: true)
        return ["unity-data", "cocos-data", "minecraft-data", "sdl-data", "ue4-data", "gta-data", "na-data", "godot-data", "flutter-data", "gm-data", "web"]
            .map { dir.appendingPathComponent($0, isDirectory: true) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    AppIcon(path: app.iconPath, size: 52)
                    TextField("名称", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { rename() }
                        .font(.system(size: 18, weight: .semibold))
                }
                .padding(.vertical, 2)
            } footer: {
                Text("在 Husk 中显示的游戏名称。游戏本身包名与内容不受影响。")
            }

            Section {
                Picker("屏幕方向", selection: $settings.orientation) {
                    ForEach(TLAppSettings.Orientation.allCases) { Text($0.title).tag($0) }
                }
                Picker("渲染分辨率", selection: $settings.resolution) {
                    ForEach(TLAppSettings.Resolution.allCases) { Text($0.title).tag($0) }
                }
                Toggle("帧率性能显示", isOn: $settings.showStats)
                Toggle("保持屏幕常亮", isOn: $settings.keepAwake)
            } header: {
                Text("显示")
            } footer: {
                Text("\(settings.resolution.detail) 屏幕方向与分辨率将在游戏下次启动时生效；当前会话中已在运行的游戏需要重新启动 Husk。")
            }

            Section {
                Picker("打开方式", selection: $settings.window) {
                    ForEach(TLAppSettings.WindowMode.allCases) { m in
                        Text(m == .auto ? "默认 (\(AppWindows.defaultWindowed ? "窗口模式" : "全屏模式"))" : m.title).tag(m)
                    }
                }
            } header: {
                Text("多任务窗口")
            } footer: {
                Text("在窗口模式下，\(app.label) 将在悬浮层中运行：拖动标题栏移动、拖动边角缩放，或最小化至屏幕边缘的快捷坞，以便同时使用 Husk 的其他功能。")
            }

            Section {
                Toggle("隐藏控制界面", isOn: $settings.cleanView)
            } header: {
                Text("纯净游戏画面")
            } footer: {
                Text("启动时不显示任何悬浮覆盖层：无操作栏、无虚拟按键、无状态信息。三指同时轻点可呼出操作栏，再次三指轻点可隐藏。游戏过程中点击栏内的隐藏按钮同样生效。")
            }

            if app.packageName == GeodeSupport.gamePackage {
                Section {
                    Toggle("Geode", isOn: $settings.geode)
                    if settings.geode { geodeStatus }
                } header: {
                    Text("Mod 模组")
                } footer: {
                    Text("Geode 是 Geometry Dash 的专属模组加载器。开启后，Husk 将自动下载适配该游戏版本的 Geode，模组可直接在游戏主界面的 Geode 按钮中浏览和安装。在游戏下次启动时生效。")
                }
            }

            Section {
                Picker("屏幕虚拟按键", selection: $settings.pad) {
                    ForEach(TLAppSettings.PadMode.allCases) { Text($0.title).tag($0) }
                }
                if settings.pad != .never {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("按键不透明度")
                        Slider(value: $settings.padOpacity, in: 0.3...1)
                    }
                    Toggle("按压振动反馈", isOn: $settings.haptics)
                }
            } header: {
                Text("控制器与按键")
            } footer: {
                Text("“自动”将在未连接实体手柄且游戏依赖控制器（如虚幻引擎游戏）时呼出虚拟手柄；“始终显示”将为支持手柄的游戏显示按键。已配对的蓝牙手柄始终可用。")
            }

            Section {
                Button { AppClip.generate(for: app) } label: {
                    Label("生成主屏快捷方式", systemImage: "apps.iphone.badge.plus")
                }
            } header: {
                Text("主屏幕")
            } footer: {
                Text("将 \(app.label) 添加至主屏幕并带有独立图标。轻点即可直接通过 Husk 启动该游戏。Husk 会下载描述文件：请打开“系统设置”，轻点“已下载描述文件”，然后点击“安装”。")
            }

            Section {
                DetailRow(label: "游戏生成的数据", value: dataSize, mono: false)
                Button(role: .destructive) { confirmReset = true } label: {
                    Label("重置游戏数据", systemImage: "arrow.counterclockwise")
                }
                .disabled(inUse || dataDirs.isEmpty)
            } header: {
                Text("数据管理")
            } footer: {
                Text(inUse ? "游戏已在本次会话中加载。请完全退出 Husk 后重新打开以重置数据。"
                           : "清除游戏在此生成并下载的所有数据：存档、设置与缓存。游戏安装包本身将保留。")
            }
        }
        .huskForm()
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { $0.save(app.id) }
        .onChange(of: settings.geode) { on in
            if on { Task { await geode.prepare(app) } } else { geode.remove(app) }
        }
        .onChange(of: nameFocused) { focused in if !focused { rename() } }
        .onDisappear { rename() }
        .task { dataSize = await Self.measure(dataDirs) }
        .confirmationDialog("重置 \(app.label) 的数据？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("重置游戏数据", role: .destructive) {
                for dir in dataDirs { try? FileManager.default.removeItem(at: dir) }
                HuskLog.log("tl", "reset the data of \(app.label)")
                Task { dataSize = await Self.measure(dataDirs) }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("该游戏在此生成的所有存档、设置和缓存将被清空。")
        }
    }

    @ViewBuilder
    private var geodeStatus: some View {
        switch geode.current(app) {
        case .idle:
            Button("下载 Geode") { Task { await geode.prepare(app) } }
        case .working(let what):
            HStack(spacing: 10) { ProgressView(); Text(what).foregroundStyle(.secondary) }
        case .ready(let version):
            LabeledContent("Geode", value: "v\(version)，已就绪")
        case .failed(let why):
            VStack(alignment: .leading, spacing: 6) {
                Text(why).font(.footnote).foregroundStyle(.orange)
                Button("重试") { Task { await geode.prepare(app) } }
            }
        }
    }

    private func rename() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != app.label else { return }
        store.rename(app, to: trimmed)
    }

    private static func measure(_ dirs: [URL]) async -> String {
        await Task.detached(priority: .utility) {
            var bytes: Int64 = 0
            for dir in dirs {
                let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
                while let url = walker?.nextObject() as? URL {
                    let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                    if values?.isRegularFile == true { bytes += Int64(values?.fileSize ?? 0) }
                }
            }
            return bytes == 0 ? "无数据" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }.value
    }
}
