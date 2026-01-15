import SwiftUI
import AppKit

/// 便利贴视图模型
class NoteViewModel: ObservableObject {
    @Published var note: Note
    @Published var attributedText: NSAttributedString

    private var saveTimer: Timer?
    private let noteStore: NoteStore

    init(note: Note, store: NoteStore = .shared) {
        self.note = note
        self.noteStore = store

        // 从 RTF 数据加载富文本
        if note.content.isEmpty {
            self.attributedText = NSAttributedString(string: "", attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.textColor
            ])
        } else {
            self.attributedText = NSAttributedString(rtf: note.content, documentAttributes: nil)
                ?? NSAttributedString(string: "")
        }

        // 监听内容变化，延迟保存
        setupAutoSave()
    }

    private func setupAutoSave() {
        // 内容变化时自动保存（防抖 1 秒）
    }

    func saveContent() {
        // 将富文本转为 RTF 数据
        let range = NSRange(location: 0, length: attributedText.length)
        if let rtfData = attributedText.rtf(from: range, documentAttributes: [:]) {
            note.content = rtfData
            note.updatedAt = Date()
            noteStore.save(note)
        }
    }

    func updateSpaceName(_ name: String) {
        note.spaceName = name
        note.updatedAt = Date()
        noteStore.save(note)
    }

    func updateSpaceID(_ spaceID: Int) {
        note.spaceID = spaceID
        // 始终更新桌面名称（除非用户自定义了名称）
        let defaultName = SpaceManager.shared.getDefaultSpaceName(for: spaceID)
        // 如果当前名称是默认格式（"桌面"或"桌面 X"），则自动更新
        if note.spaceName == "桌面" || note.spaceName.hasPrefix("桌面 ") {
            note.spaceName = defaultName
        }
        noteStore.save(note)
    }

    func updateBackgroundColor(_ hex: String) {
        note.backgroundColor = hex
        note.updatedAt = Date()
        noteStore.save(note)
    }

    func closeWindow() {
        saveContent()
        // 发送关闭通知
        NotificationCenter.default.post(
            name: .closeNoteWindow,
            object: note.id
        )
    }

    deinit {
        saveTimer?.invalidate()
    }
}
