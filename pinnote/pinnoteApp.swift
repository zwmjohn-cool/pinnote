//
//  pinnoteApp.swift
//  pinnote
//
//  Created by zwm on 1/14/26.
//

import SwiftUI

// MARK: - 通知名称
extension Notification.Name {
    static let createNewNote = Notification.Name("createNewNote")
    static let closeNoteWindow = Notification.Name("closeNoteWindow")
    static let openNoteWindow = Notification.Name("openNoteWindow")
    static let updateWindowLevel = Notification.Name("updateWindowLevel")
}

// MARK: - 全局窗口管理器
class WindowManager: ObservableObject {
    static let shared = WindowManager()
    var openWindowAction: ((UUID) -> Void)?
}

@main
struct pinnoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var noteStore = NoteStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // 菜单栏
        MenuBarExtra("PinNote", image: "MenuBarIcon") {
            MenuBarView(noteStore: noteStore)
        }
        .menuBarExtraStyle(.window)

        // 便利贴窗口组
        WindowGroup(id: "note", for: UUID.self) { $noteID in
            NoteWindowContainer(noteID: noteID, noteStore: noteStore)
                .onAppear {
                    // 注册 openWindow 动作
                    WindowManager.shared.openWindowAction = { id in
                        openWindow(id: "note", value: id)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 300, height: 300)
        .defaultPosition(.center)

        // 设置窗口
        Settings {
            SettingsView()
        }
    }
}

// MARK: - 菜单栏视图
struct MenuBarView: View {
    @ObservedObject var noteStore: NoteStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("便利贴")
                    .font(.headline)
                Spacer()
                Button(action: createNewNote) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .help("新建便利贴")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // 便利贴列表
            if noteStore.notes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("暂无便利贴")
                        .foregroundStyle(.secondary)
                    Button("创建第一个便利贴") {
                        createNewNote()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(noteStore.notes) { note in
                            NoteListItem(note: note) {
                                openNoteAndSwitchToSpace(note)
                            } onDelete: {
                                noteStore.delete(note)
                            } onTogglePin: {
                                noteStore.togglePin(note)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // 底部按钮
            HStack {
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Text("\(noteStore.notes.count) 个便利贴")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 280, height: 350)
    }

    private func createNewNote() {
        let newNote = noteStore.createNote()
        openWindow(id: "note", value: newNote.id)
        // 延迟激活窗口，确保窗口已创建
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private func openNoteAndSwitchToSpace(_ note: Note) {
        // 打开窗口（如果窗口已存在则无操作）
        openWindow(id: "note", value: note.id)

        // 延迟激活窗口，确保窗口已创建并注册到 NoteWindowTracker
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let window = NoteWindowTracker.shared.window(for: note.id) {
                // 激活窗口会自动切换到该窗口所在的桌面
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
                print("[MenuBarView] 激活便利贴窗口: \(note.spaceName) (ID: \(note.spaceID))")
            } else {
                print("[MenuBarView] 警告: 无法找到便利贴窗口: \(note.id)")
            }
        }
    }
}

// MARK: - 便利贴列表项
struct NoteListItem: View {
    let note: Note
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // 颜色指示
            RoundedRectangle(cornerRadius: 4)
                .fill(note.color)
                .frame(width: 6, height: 40)

            // 内容预览
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(note.spaceName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    // Pin 状态图标（已隐藏）
//                    if note.isPinned {
//                        Image(systemName: "pin.fill")
//                            .font(.system(size: 8))
//                            .foregroundStyle(.orange)
//                    }
                }

                Text(notePreview)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 操作按钮
            if isHovering {
                HStack(spacing: 4) {
                    // Pin/Unpin 按钮（已隐藏）
//                    Button {
//                        onTogglePin()
//                    } label: {
//                        Image(systemName: note.isPinned ? "pin.slash.fill" : "pin.fill")
//                            .font(.system(size: 12))
//                            .foregroundStyle(note.isPinned ? .orange : .gray)
//                            .frame(width: 24, height: 24)
//                            .contentShape(Rectangle())
//                    }
//                    .buttonStyle(.plain)
//                    .help(note.isPinned ? "取消置后" : "置于最后")

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("删除")
                }
                .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var notePreview: String {
        if note.content.isEmpty {
            return "空白便利贴"
        }

        // 解析 RTF 数据获取纯文本
        if let attrString = NSAttributedString(rtf: note.content, documentAttributes: nil) {
            let text = attrString.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }

        return "空白便利贴"
    }
}

// MARK: - 窗口容器视图
struct NoteWindowContainer: View {
    let noteID: UUID?
    @ObservedObject var noteStore: NoteStore
    @State private var viewModel: NoteViewModel?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if let vm = viewModel {
                NoteWindow(viewModel: vm)
                    .frame(minWidth: 200, minHeight: 200)
            } else {
                ProgressView()
                    .onAppear {
                        setupViewModel()
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewNote)) { _ in
            let newNote = noteStore.createNote()
            openWindow(id: "note", value: newNote.id)
        }
    }

    private func setupViewModel() {
        if let noteID = noteID, let note = noteStore.note(for: noteID) {
            viewModel = NoteViewModel(note: note, store: noteStore)
        } else {
            let newNote = noteStore.createNote()
            viewModel = NoteViewModel(note: newNote, store: noteStore)
        }
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    var body: some View {
        Form {
            Text("PinNote 设置")
                .font(.headline)
            Text("便利贴应用 - 帮助你标记每个桌面的用途")
                .foregroundStyle(.secondary)

            Divider()

            Text("提示：双击便利贴顶部的桌面名称可以自定义名称")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 350, height: 200)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 监听关闭窗口通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloseNote),
            name: .closeNoteWindow,
            object: nil
        )
    }

    @objc private func handleCloseNote(_ notification: Notification) {
        // 根据 noteID 找到对应窗口并关闭
        if let noteID = notification.object as? UUID,
           let window = NoteWindowTracker.shared.window(for: noteID) {
            window.close()
        } else if let keyWindow = NSApplication.shared.keyWindow {
            // 兜底：关闭当前 key window
            keyWindow.close()
        }
    }
}
