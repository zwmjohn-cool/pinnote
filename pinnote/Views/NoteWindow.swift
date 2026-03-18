import SwiftUI
import AppKit

private let noteTitleHostIdentifier = NSUserInterfaceItemIdentifier("PinNoteTitleHost")

private struct WindowTitleAccessoryView: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}

// MARK: - 窗口管理器（用于追踪每个便利贴的窗口）
class NoteWindowTracker: ObservableObject {
    static let shared = NoteWindowTracker()
    private var windowMap: [UUID: NSWindow] = [:]

    func register(noteID: UUID, window: NSWindow) {
        windowMap[noteID] = window
    }

    func unregister(noteID: UUID) {
        windowMap.removeValue(forKey: noteID)
    }

    func window(for noteID: UUID) -> NSWindow? {
        return windowMap[noteID]
    }
}

// MARK: - 窗口访问器（用于获取 NSWindow 引用）
struct WindowAccessor: NSViewRepresentable {
    let noteID: UUID
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindow(window)
            }
        }
    }
}

/// 便利贴主窗口视图
struct NoteWindow: View {
    @ObservedObject var viewModel: NoteViewModel
    @StateObject private var spaceManager = SpaceManager.shared
    @State private var isEditing = false
    @State private var isHovering = false
    @State private var currentWindow: NSWindow?
    @State private var configuredWindowNumber: Int?

    private var pinnedWindowLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
    }

    private var showsToolbar: Bool {
        isHovering || isEditing
    }

    var body: some View {
        ZStack(alignment: .top) {
            RichTextEditor(
                attributedText: $viewModel.attributedText,
                isEditing: $isEditing,
                backgroundColor: viewModel.note.color,
                textColor: viewModel.note.nsTextColor,
                topInset: showsToolbar ? 40 : 8
            )
            .frame(minWidth: 200, minHeight: 150)
            .allowsHitTesting(!viewModel.note.isPinned)

            ToolbarView(
                onFormat: { command in
                    if let textView = NSApplication.shared.currentTextView {
                        command.apply(to: textView)
                    }
                },
                onColorChange: { hex in
                    viewModel.updateBackgroundColor(hex)
                },
                currentColor: viewModel.note.backgroundColor
            )
            .opacity(showsToolbar ? 1 : 0)
            .allowsHitTesting(showsToolbar)
        }
        .background(viewModel.note.color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .background(
            // 使用 WindowAccessor 获取并追踪窗口引用
            WindowAccessor(noteID: viewModel.note.id) { window in
                currentWindow = window
                NoteWindowTracker.shared.register(noteID: viewModel.note.id, window: window)
                configureWindow(window)
            }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsToolbar)
        .onAppear {
            // 只在首次创建时设置桌面空间（spaceID == 0 表示新建的便利贴）
            if viewModel.note.spaceID == 0 {
                let currentSpaceID = spaceManager.getCurrentSpaceID()
                viewModel.updateSpaceID(currentSpaceID)
            }
            viewModel.refreshSpaceNameFromCurrentSpaceID()
            if let window = currentWindow ?? NoteWindowTracker.shared.window(for: viewModel.note.id) {
                configureWindow(window)
            }
            // 延迟应用已保存的 pin 状态，确保窗口已经被追踪
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyWindowLevel(isPinned: viewModel.note.isPinned)
            }
        }
        .onChange(of: viewModel.note.spaceName) { _, newName in
            updateWindowTitle(newName)
        }
        .onDisappear {
            NoteWindowTracker.shared.unregister(noteID: viewModel.note.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateWindowLevel)) { notification in
            if let noteID = notification.object as? UUID,
               noteID == viewModel.note.id,
               let isPinned = notification.userInfo?["isPinned"] as? Bool {
                applyWindowLevel(isPinned: isPinned)
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
            // 桌面切换时检查窗口是否在新桌面上，延迟等待系统更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.refreshSpaceNameFromCurrentSpaceID()
                checkAndUpdateWindowSpace()
            }
            // 再次延迟检查，确保捕获到变化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.refreshSpaceNameFromCurrentSpaceID()
                checkAndUpdateWindowSpace()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .spacesConfigurationDidChange)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.refreshSpaceNameFromCurrentSpaceID()
                checkAndUpdateWindowSpace()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification)) { notification in
            // 窗口移动到其他屏幕时检查
            if let window = notification.object as? NSWindow,
               window == currentWindow {
                checkAndUpdateWindowSpace()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { notification in
            if let window = notification.object as? NSWindow,
               window == currentWindow {
                persistWindowFrame(window)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMoveNotification)) { notification in
            // 窗口拖动结束时检查是否移动到其他桌面
            if let window = notification.object as? NSWindow,
               window == currentWindow {
                persistWindowFrame(window)
                // 延迟检查，等待系统更新窗口所在空间
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    checkAndUpdateWindowSpace()
                }
            }
        }
    }

    /// 检查窗口所在桌面并更新显示
    private func checkAndUpdateWindowSpace() {
        guard let window = currentWindow ?? NoteWindowTracker.shared.window(for: viewModel.note.id) else {
            print("[NoteWindow] checkAndUpdateWindowSpace: 无法获取窗口")
            return
        }

        let windowNumber = window.windowNumber
        print("[NoteWindow] 检查窗口 \(windowNumber), 当前记录 spaceID: \(viewModel.note.spaceID)")

        if let newSpaceID = spaceManager.getSpaceID(for: windowNumber) {
            print("[NoteWindow] 窗口实际所在 spaceID: \(newSpaceID)")
            if newSpaceID != viewModel.note.spaceID {
                viewModel.updateSpaceID(newSpaceID)
                print("[NoteWindow] 窗口 \(viewModel.note.id) 移动到新桌面: \(spaceManager.getDefaultSpaceName(for: newSpaceID))")
            }
        } else {
            // 如果无法获取窗口所在空间，使用当前活动空间
            let currentSpaceID = spaceManager.getCurrentSpaceID()
            print("[NoteWindow] 无法获取窗口空间，使用当前活动空间: \(currentSpaceID)")
            if currentSpaceID != viewModel.note.spaceID {
                viewModel.updateSpaceID(currentSpaceID)
                print("[NoteWindow] 窗口 \(viewModel.note.id) 更新到当前桌面: \(spaceManager.getDefaultSpaceName(for: currentSpaceID))")
            }
        }
    }

    private func applyWindowLevel(isPinned: Bool) {
        // 优先使用已追踪的窗口，其次使用 NoteWindowTracker
        guard let window = currentWindow ?? NoteWindowTracker.shared.window(for: viewModel.note.id) else {
            print("[NoteWindow] 无法找到窗口: \(viewModel.note.id)")
            return
        }

        if isPinned {
            // 置于所有窗口最后（桌面之上、普通窗口之下），仍保留可交互的标题栏/边缘
            window.level = pinnedWindowLevel
            window.collectionBehavior = [.managed]
            window.orderBack(nil)
            print("[NoteWindow] 窗口已置后: \(viewModel.note.id)")
        } else {
            // 恢复正常层级并置于最前
            window.level = .normal
            window.collectionBehavior = []
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
            print("[NoteWindow] 窗口已置前: \(viewModel.note.id)")
        }
    }

    private func activateWindow() {
        guard let window = currentWindow ?? NoteWindowTracker.shared.window(for: viewModel.note.id) else {
            return
        }
        // 临时提升窗口层级以便激活
        window.level = .normal
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // 如果是 pin 状态，延迟恢复桌面层级
        if viewModel.note.isPinned {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.level = pinnedWindowLevel
                window.orderBack(nil)
            }
        }
    }

    private func configureWindow(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true

        if configuredWindowNumber != window.windowNumber {
            applySavedWindowSize(to: window)
            configuredWindowNumber = window.windowNumber
        }

        updateWindowTitle(viewModel.note.spaceName)
    }

    private func applySavedWindowSize(to window: NSWindow) {
        let width = max(viewModel.note.windowWidth, AppSettings.minNoteWidth)
        let height = max(viewModel.note.windowHeight, AppSettings.minNoteHeight)
        let targetSize = CGSize(width: width, height: height)

        guard window.frame.size != targetSize else {
            return
        }

        var frame = window.frame
        frame.size = targetSize
        window.setFrame(frame, display: true)
    }

    private func persistWindowFrame(_ window: NSWindow) {
        viewModel.updateWindowFrame(window.frame)
    }

    private func updateWindowTitle(_ title: String) {
        guard let window = currentWindow ?? NoteWindowTracker.shared.window(for: viewModel.note.id) else {
            return
        }

        window.title = title
        guard let titlebarView = window.standardWindowButton(.closeButton)?.superview,
              let zoomButton = window.standardWindowButton(.zoomButton),
              let closeButton = window.standardWindowButton(.closeButton) else {
            return
        }

        if let titleHost = titlebarView.subviews
            .first(where: { $0.identifier == noteTitleHostIdentifier }) as? NSHostingView<WindowTitleAccessoryView> {
            titleHost.rootView = WindowTitleAccessoryView(title: title)
            titleHost.invalidateIntrinsicContentSize()
        } else {
            let titleHost = NSHostingView(rootView: WindowTitleAccessoryView(title: title))
            titleHost.identifier = noteTitleHostIdentifier
            titleHost.translatesAutoresizingMaskIntoConstraints = false
            titlebarView.addSubview(titleHost)

            NSLayoutConstraint.activate([
                titleHost.leadingAnchor.constraint(equalTo: zoomButton.trailingAnchor, constant: 14),
                titleHost.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor)
            ])
        }
    }
}

// MARK: - 预览
#Preview {
    NoteWindow(viewModel: NoteViewModel(note: Note()))
        .frame(width: 300, height: 300)
}
