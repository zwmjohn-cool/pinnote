import SwiftUI
import AppKit
import Combine

/// 便利贴视图模型
class NoteViewModel: ObservableObject {
    @Published var note: Note
    @Published var attributedText: NSAttributedString

    private var saveTimer: Timer?
    private let noteStore: NoteStore
    private var cancellables = Set<AnyCancellable>()

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

        // 监听 pin 状态变化通知
        setupPinObserver()
    }

    private func setupPinObserver() {
        NotificationCenter.default.publisher(for: .updateWindowLevel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let noteID = notification.object as? UUID,
                      noteID == self.note.id,
                      let isPinned = notification.userInfo?["isPinned"] as? Bool else {
                    return
                }
                self.note.isPinned = isPinned
            }
            .store(in: &cancellables)
    }

    private func setupAutoSave() {
        // 监听 attributedText 变化，延迟保存（防抖 1 秒）
        $attributedText
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveContent()
            }
            .store(in: &cancellables)
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
        // 如果当前名称是默认格式，则自动更新
        // 匹配格式："桌面"、"桌面 X"、"主屏 桌面 X"、"副屏Y 桌面 X"、"全屏应用"
        let isDefaultFormat = note.spaceName == "桌面" ||
                              note.spaceName == "全屏应用" ||
                              note.spaceName.hasPrefix("桌面 ") ||
                              note.spaceName.hasPrefix("主屏 桌面") ||
                              note.spaceName.hasPrefix("副屏")
        if isDefaultFormat {
            note.spaceName = defaultName
        }
        noteStore.save(note)
    }

    func updateBackgroundColor(_ hex: String) {
        note.backgroundColor = hex
        note.updatedAt = Date()
        noteStore.save(note)
    }

    func togglePinned() {
        note.isPinned.toggle()
        note.updatedAt = Date()
        noteStore.save(note)
        // 发送通知更新窗口层级
        NotificationCenter.default.post(
            name: .updateWindowLevel,
            object: note.id,
            userInfo: ["isPinned": note.isPinned]
        )
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
