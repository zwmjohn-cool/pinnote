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
}

@main
struct pinnoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var noteStore = NoteStore.shared

    var body: some Scene {
        // 便利贴窗口组
        WindowGroup(id: "note", for: UUID.self) { $noteID in
            NoteWindowContainer(noteID: noteID, noteStore: noteStore)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 300, height: 300)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建便利贴") {
                    NotificationCenter.default.post(name: .createNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        // 设置窗口
        Settings {
            SettingsView()
        }
    }
}

// MARK: - 窗口容器视图
struct NoteWindowContainer: View {
    let noteID: UUID?
    @ObservedObject var noteStore: NoteStore
    @State private var viewModel: NoteViewModel?

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
    private var openWindowAction: ((UUID) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 首次启动检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.restoreNotesIfNeeded()
        }

        // 监听创建新便利贴的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCreateNewNote),
            name: .createNewNote,
            object: nil
        )

        // 监听关闭窗口通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloseNote),
            name: .closeNoteWindow,
            object: nil
        )
    }

    private func restoreNotesIfNeeded() {
        let store = NoteStore.shared
        if store.notes.isEmpty {
            // 首次启动，创建一个默认便利贴
            _ = store.createNote()
        }
    }

    @objc private func handleCreateNewNote(_ notification: Notification) {
        // 通过菜单栏触发新窗口 - SwiftUI 会自动处理
    }

    @objc private func handleCloseNote(_ notification: Notification) {
        guard let noteID = notification.object as? UUID else { return }
        // 关闭对应的窗口
        for window in NSApplication.shared.windows {
            if window.title.contains(noteID.uuidString) {
                window.close()
                break
            }
        }
    }
}
