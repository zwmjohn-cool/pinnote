import SwiftUI
import AppKit

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

    private var pinnedWindowLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏 - 显示桌面空间信息
            HeaderView(
                spaceName: viewModel.note.spaceName,
                spaceID: viewModel.note.spaceID,
                isPinned: viewModel.note.isPinned,
                isHovering: isHovering,
                onClose: { viewModel.closeWindow() },
                onSpaceNameChange: { newName in
                    viewModel.updateSpaceName(newName)
                },
                onTogglePin: {
                    viewModel.togglePinned()
                },
                onActivate: {
                    activateWindow()
                }
            )

            // 工具栏
            if isHovering || isEditing {
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 富文本编辑器
            RichTextEditor(
                attributedText: $viewModel.attributedText,
                backgroundColor: viewModel.note.color,
                textColor: viewModel.note.nsTextColor
            )
            .frame(minWidth: 200, minHeight: 150)
            .allowsHitTesting(!viewModel.note.isPinned)
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
            }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onAppear {
            // 只在首次创建时设置桌面空间（spaceID == 0 表示新建的便利贴）
            if viewModel.note.spaceID == 0 {
                let currentSpaceID = spaceManager.getCurrentSpaceID()
                viewModel.updateSpaceID(currentSpaceID)
            }
            // 延迟应用已保存的 pin 状态，确保窗口已经被追踪
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyWindowLevel(isPinned: viewModel.note.isPinned)
            }
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
                checkAndUpdateWindowSpace()
            }
            // 再次延迟检查，确保捕获到变化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMoveNotification)) { notification in
            // 窗口拖动结束时检查是否移动到其他桌面
            if let window = notification.object as? NSWindow,
               window == currentWindow {
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
}

// MARK: - 顶部标题栏
struct HeaderView: View {
    let spaceName: String
    let spaceID: Int
    let isPinned: Bool
    let isHovering: Bool
    let onClose: () -> Void
    let onSpaceNameChange: (String) -> Void
    let onTogglePin: () -> Void
    let onActivate: () -> Void

    @State private var isEditingName = false
    @State private var editedName: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // 关闭按钮
            if isHovering {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            // 桌面空间标识
            if isEditingName {
                TextField("空间名称", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: 150)
                    .onSubmit {
                        onSpaceNameChange(editedName)
                        isEditingName = false
                    }
                    .onExitCommand {
                        isEditingName = false
                    }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 10))
                    Text(spaceName)
                        .font(.system(size: 12, weight: .medium))
                    // Pin 状态图标（已隐藏）
//                    if isPinned {
//                        Image(systemName: "pin.fill")
//                            .font(.system(size: 8))
//                            .foregroundStyle(.orange)
//                    }
                }
                .foregroundStyle(.black)
                .onTapGesture(count: 2) {
                    editedName = spaceName
                    isEditingName = true
                }
            }

            Spacer()

            // Pin 按钮 - 置顶/置底切换（已隐藏）
//            if isHovering {
//                Button(action: onTogglePin) {
//                    Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
//                        .font(.system(size: 12))
//                        .foregroundStyle(isPinned ? .orange : .black)
//                }
//                .buttonStyle(.plain)
//                .help(isPinned ? "取消置后" : "置于最后")
//                .transition(.opacity)
//            }

            // 新建便利贴按钮
            if isHovering {
                Button(action: {
                    NotificationCenter.default.post(name: .createNewNote, object: nil)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white)
        .contentShape(Rectangle())
        .onTapGesture {
            onActivate()
        }
    }
}

// MARK: - 预览
#Preview {
    NoteWindow(viewModel: NoteViewModel(note: Note()))
        .frame(width: 300, height: 300)
}
