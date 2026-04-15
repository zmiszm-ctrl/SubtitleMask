import AppKit
import SwiftUI

enum AppStorageKeys {
  static let opacity = "mask.opacity"
  static let cornerRadius = "mask.cornerRadius"
  static let selectedIndex = "mask.selectedIndex"
  static let maskFrame = "window.mask.frame"
  static let buttonFrame = "window.button.frame"
  static let settingsFrame = "window.settings.frame"
}

enum FrameStore {
  static func save(_ frame: NSRect, key: String) {
    UserDefaults.standard.set(NSStringFromRect(frame), forKey: key)
  }

  static func load(_ key: String, fallback: NSRect) -> NSRect {
    guard let text = UserDefaults.standard.string(forKey: key) else { return fallback }
    let rect = NSRectFromString(text)
    return rect.equalTo(.zero) ? fallback : rect
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var maskWindowController: MaskWindowController?
  private var buttonWindowController: FloatingButtonWindowController?
  private var settingsWindowController: SettingsWindowController?
  private var keyMonitor: Any?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    let viewModel = MaskViewModel()
    let settingsController = SettingsWindowController(viewModel: viewModel)
    let buttonController = FloatingButtonWindowController {
      settingsController.togglePanel()
    }
    let maskController = MaskWindowController(viewModel: viewModel)

    maskWindowController = maskController
    settingsWindowController = settingsController
    buttonWindowController = buttonController

    maskController.showWindow(nil)
    buttonController.showWindow(nil)
    settingsController.showWindow(nil)
    settingsController.closePanel()

    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak viewModel] event in
      guard let viewModel else { return event }
      let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      if flags.contains(.command), flags.contains(.shift) {
        if event.charactersIgnoringModifiers == "]" {
          viewModel.nextPattern()
          return nil
        }
        if event.charactersIgnoringModifiers == "[" {
          viewModel.prevPattern()
          return nil
        }
      }
      return event
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
    }
  }
}

@MainActor
final class MaskWindowController: NSWindowController, NSWindowDelegate {
  init(viewModel: MaskViewModel) {
    let content = MaskView(viewModel: viewModel)
    let defaultFrame = NSRect(x: 220, y: 220, width: 900, height: 80)
    let savedFrame = FrameStore.load(AppStorageKeys.maskFrame, fallback: defaultFrame)
    let window = NSWindow(
      contentRect: savedFrame,
      styleMask: [.borderless, .resizable],
      backing: .buffered,
      defer: false
    )

    window.isOpaque = false
    window.backgroundColor = .clear
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.hasShadow = true
    window.isMovableByWindowBackground = true
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.minSize = NSSize(width: 120, height: 10)
    window.maxSize = NSSize(width: 5000, height: 5000)

    let hosting = NSHostingView(rootView: content)
    hosting.wantsLayer = true
    hosting.layer?.backgroundColor = NSColor.clear.cgColor
    window.contentView = hosting

    super.init(window: window)
    window.delegate = self
    window.orderFrontRegardless()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func windowDidMove(_ notification: Notification) {
    guard let frame = window?.frame else { return }
    FrameStore.save(frame, key: AppStorageKeys.maskFrame)
  }

  func windowDidEndLiveResize(_ notification: Notification) {
    guard let frame = window?.frame else { return }
    FrameStore.save(frame, key: AppStorageKeys.maskFrame)
  }
}

@MainActor
final class MaskViewModel: ObservableObject {
  @Published var opacity: Double = 0.92 {
    didSet { UserDefaults.standard.set(opacity, forKey: AppStorageKeys.opacity) }
  }
  @Published var cornerRadius: Double = 16 {
    didSet { UserDefaults.standard.set(cornerRadius, forKey: AppStorageKeys.cornerRadius) }
  }
  @Published var patterns: [Pattern] = []
  @Published var selectedIndex: Int = 0 {
    didSet { UserDefaults.standard.set(selectedIndex, forKey: AppStorageKeys.selectedIndex) }
  }
  let patternFolderURL: URL?

  init() {
    if UserDefaults.standard.object(forKey: AppStorageKeys.opacity) != nil {
      opacity = UserDefaults.standard.double(forKey: AppStorageKeys.opacity)
    }
    if UserDefaults.standard.object(forKey: AppStorageKeys.cornerRadius) != nil {
      cornerRadius = UserDefaults.standard.double(forKey: AppStorageKeys.cornerRadius)
    }

    let result = PatternLoader.loadPatterns()
    patterns = result.patterns
    patternFolderURL = result.folderURL
    if patterns.isEmpty {
      patterns = [.init(name: "Solid Black", kind: .solid(color: .black))]
    }
    let savedIndex = UserDefaults.standard.integer(forKey: AppStorageKeys.selectedIndex)
    selectedIndex = min(max(savedIndex, 0), max(patterns.count - 1, 0))
  }

  var selectedPattern: Pattern {
    patterns[min(max(selectedIndex, 0), patterns.count - 1)]
  }

  func nextPattern() {
    guard !patterns.isEmpty else { return }
    selectedIndex = (selectedIndex + 1) % patterns.count
  }

  func prevPattern() {
    guard !patterns.isEmpty else { return }
    selectedIndex = (selectedIndex - 1 + patterns.count) % patterns.count
  }

  func openPatternFolder() {
    guard let patternFolderURL else { return }
    NSWorkspace.shared.open(patternFolderURL)
  }
}

@MainActor
final class FloatingButtonWindowController: NSWindowController, NSWindowDelegate {
  private var snapWorkItem: DispatchWorkItem?

  init(onTap: @escaping () -> Void) {
    let buttonView = FloatingButtonView(onTap: onTap)
    let defaultFrame = NSRect(x: 90, y: 220, width: 56, height: 56)
    let savedFrame = FrameStore.load(AppStorageKeys.buttonFrame, fallback: defaultFrame)
    let window = NSWindow(
      contentRect: savedFrame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    window.isOpaque = false
    window.backgroundColor = .clear
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.hasShadow = true
    window.isMovableByWindowBackground = true

    let hosting = NSHostingView(rootView: buttonView)
    hosting.wantsLayer = true
    hosting.layer?.backgroundColor = NSColor.clear.cgColor
    window.contentView = hosting

    super.init(window: window)
    window.delegate = self
    window.orderFrontRegardless()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func windowDidMove(_ notification: Notification) {
    guard let frame = window?.frame else { return }
    FrameStore.save(frame, key: AppStorageKeys.buttonFrame)
    scheduleSnapToEdge()
  }

  private func scheduleSnapToEdge() {
    snapWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
      self?.snapToNearestScreenEdge()
    }
    snapWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
  }

  private func snapToNearestScreenEdge() {
    guard let window else { return }
    guard let screen = window.screen ?? NSScreen.main else { return }

    var frame = window.frame
    let visible = screen.visibleFrame
    let margin: CGFloat = 8
    let leftDistance = abs(frame.minX - visible.minX)
    let rightDistance = abs(visible.maxX - frame.maxX)

    frame.origin.x = leftDistance <= rightDistance
      ? visible.minX + margin
      : visible.maxX - frame.width - margin
    frame.origin.y = min(max(frame.origin.y, visible.minY + margin), visible.maxY - frame.height - margin)

    window.setFrame(frame, display: true, animate: true)
    FrameStore.save(frame, key: AppStorageKeys.buttonFrame)
  }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  init(viewModel: MaskViewModel) {
    let content = SettingsPanelView(viewModel: viewModel)
    let defaultFrame = NSRect(x: 170, y: 220, width: 430, height: 420)
    let savedFrame = FrameStore.load(AppStorageKeys.settingsFrame, fallback: defaultFrame)
    let panel = NSPanel(
      contentRect: savedFrame,
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    panel.title = "字幕遮挡设置"
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false

    let hosting = NSHostingView(rootView: content)
    panel.contentView = hosting

    super.init(window: panel)
    panel.delegate = self
  }

  func togglePanel() {
    guard let panel = window else { return }
    if panel.isVisible {
      panel.orderOut(nil)
    } else {
      panel.makeKeyAndOrderFront(nil)
    }
  }

  func closePanel() {
    window?.orderOut(nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func windowDidMove(_ notification: Notification) {
    guard let frame = window?.frame else { return }
    FrameStore.save(frame, key: AppStorageKeys.settingsFrame)
  }
}

struct Pattern: Identifiable, Hashable {
  enum Kind: Hashable {
    case image(url: URL)
    case solid(color: NSColor)
  }

  let id = UUID()
  let name: String
  let kind: Kind
}

struct PatternLoadResult {
  let folderURL: URL?
  let patterns: [Pattern]
}

enum PatternLoader {
  static func loadPatterns() -> PatternLoadResult {
    let fm = FileManager.default
    let candidates: [URL] = {
      var urls: [URL] = []
      if let bundleResources = Bundle.main.resourceURL {
        urls.append(bundleResources.appendingPathComponent("image", isDirectory: true))
      }
      if let env = ProcessInfo.processInfo.environment["SUBTITLE_MASK_ASSETS"], !env.isEmpty {
        urls.append(URL(fileURLWithPath: env, isDirectory: true))
      }
      let cwd = URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)
      urls.append(cwd.appendingPathComponent("image", isDirectory: true))
      urls.append(cwd.appendingPathComponent("../image", isDirectory: true))
      urls.append(cwd.appendingPathComponent("../../subtitle tool/image", isDirectory: true))
      return urls
    }()

    guard let folder = candidates.first(where: { fm.fileExists(atPath: $0.path) }) else {
      return PatternLoadResult(folderURL: nil, patterns: [])
    }

    guard let entries = try? fm.contentsOfDirectory(
      at: folder,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return PatternLoadResult(folderURL: folder, patterns: [])
    }

    let pngs = entries
      .filter { $0.pathExtension.lowercased() == "png" }
      .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

    let patterns = pngs.map { url in
      Pattern(name: url.deletingPathExtension().lastPathComponent, kind: .image(url: url))
    }
    return PatternLoadResult(folderURL: folder, patterns: patterns)
  }
}

struct MaskView: View {
  @ObservedObject var viewModel: MaskViewModel

  var body: some View {
    PatternBackground(pattern: viewModel.selectedPattern)
      .opacity(viewModel.opacity)
      .clipShape(RoundedRectangle(cornerRadius: viewModel.cornerRadius, style: .continuous))
      .contentShape(Rectangle())
      .background(Color.clear)
  }
}

struct FloatingButtonView: View {
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      ZStack {
        Circle().fill(.ultraThinMaterial)
        Image(systemName: "slider.horizontal.3")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.primary)
      }
      .frame(width: 56, height: 56)
    }
    .buttonStyle(.plain)
  }
}

struct SettingsPanelView: View {
  @ObservedObject var viewModel: MaskViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("调整选项").font(.headline)

      HStack(spacing: 8) {
        Button("◀︎ 上一张") { viewModel.prevPattern() }
        Button("下一张 ▶︎") { viewModel.nextPattern() }
      }

      Picker("图案", selection: $viewModel.selectedIndex) {
        ForEach(Array(viewModel.patterns.enumerated()), id: \.offset) { idx, p in
          Text(p.name).tag(idx)
        }
      }

      HStack {
        Text("透明度").frame(width: 64, alignment: .leading)
        Slider(value: $viewModel.opacity, in: 0.2...1.0)
      }

      HStack {
        Text("圆角").frame(width: 64, alignment: .leading)
        Slider(value: $viewModel.cornerRadius, in: 0...32)
      }

      Divider()
      Text("操作说明").font(.headline)
      Text("1. 遮挡条可拖拽移动，边缘可自由缩放。最小高度支持到 10 像素。")
      Text("2. 左侧独立悬浮按钮不覆盖遮挡条，点击即可打开/关闭本设置面板。")
      Text("3. 快捷键：⌘⇧] 下一张，⌘⇧[ 上一张。")
        .foregroundStyle(.secondary)

      HStack {
        Button("图案文件夹") { viewModel.openPatternFolder() }
        Spacer()
        Button("关闭程序") { NSApplication.shared.terminate(nil) }
          .keyboardShortcut("q", modifiers: [.command])
      }
    }
    .padding(16)
    .frame(width: 430, height: 420, alignment: .topLeading)
  }
}

struct PatternBackground: NSViewRepresentable {
  let pattern: Pattern

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.layer = CALayer()
    view.layer?.masksToBounds = true
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    guard let layer = nsView.layer else { return }
    switch pattern.kind {
    case .solid(let color):
      layer.backgroundColor = color.cgColor
      layer.contents = nil
    case .image(let url):
      layer.backgroundColor = NSColor.black.cgColor
      if let img = NSImage(contentsOf: url) {
        layer.contents = img
        layer.contentsGravity = .resizeAspectFill
      } else {
        layer.contents = nil
      }
    }
  }
}

@main
struct SubtitleMaskMain {
  @MainActor
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }
}

