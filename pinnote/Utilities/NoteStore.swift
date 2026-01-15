import Foundation
import SwiftUI

/// 便利贴数据存储管理
class NoteStore: ObservableObject {
    static let shared = NoteStore()

    @Published var notes: [Note] = []

    private let saveKey = "pinnote_notes"
    private let fileManager = FileManager.default

    private var saveURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("PinNote", isDirectory: true)

        // 确保目录存在
        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }

        return appFolder.appendingPathComponent("notes.json")
    }

    private init() {
        loadNotes()
    }

    // MARK: - 加载
    func loadNotes() {
        guard fileManager.fileExists(atPath: saveURL.path) else {
            notes = []
            return
        }

        do {
            let data = try Data(contentsOf: saveURL)
            notes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            print("加载便利贴失败: \(error)")
            notes = []
        }
    }

    // MARK: - 保存
    func save(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
        persistNotes()
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        persistNotes()
    }

    func delete(id: UUID) {
        notes.removeAll { $0.id == id }
        persistNotes()
    }

    private func persistNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("保存便利贴失败: \(error)")
        }
    }

    // MARK: - 查询
    func note(for id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    func notes(for spaceID: Int) -> [Note] {
        notes.filter { $0.spaceID == spaceID }
    }

    // MARK: - 创建新便利贴
    func createNote(spaceID: Int? = nil) -> Note {
        let currentSpaceID = spaceID ?? SpaceManager.shared.getCurrentSpaceID()
        let spaceName = SpaceManager.shared.getDefaultSpaceName(for: currentSpaceID)

        var note = Note(
            spaceID: currentSpaceID,
            spaceName: spaceName
        )

        // 随机选择一个颜色
        let randomColor = Note.presetColors.randomElement()?.hex ?? "#FFFACD"
        note.backgroundColor = randomColor

        save(note)
        return note
    }
}
