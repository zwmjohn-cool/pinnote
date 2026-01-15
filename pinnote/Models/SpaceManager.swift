import Foundation
import AppKit

/// 桌面空间管理器 - 使用私有 API 获取当前桌面空间 ID
class SpaceManager: ObservableObject {
    static let shared = SpaceManager()

    @Published var currentSpaceID: Int = 0
    @Published var currentSpaceIndex: Int = 1

    // MARK: - 私有 API 声明
    @_silgen_name("CGSDefaultConnectionForThread")
    private static func CGSDefaultConnectionForThread() -> Int32

    @_silgen_name("CGSGetActiveSpace")
    private static func CGSGetActiveSpace(_ connection: Int32) -> Int

    @_silgen_name("CGSCopyManagedDisplaySpaces")
    private static func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray?

    private init() {
        updateCurrentSpace()
        setupNotifications()
        // 打印调试信息
        debugPrintSpaces()
    }

    private func setupNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func spaceDidChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateCurrentSpace()
            print("[SpaceManager] 桌面切换 -> Space ID: \(self.currentSpaceID), Index: \(self.currentSpaceIndex)")
        }
    }

    func updateCurrentSpace() {
        let connection = Self.CGSDefaultConnectionForThread()
        let spaceID = Self.CGSGetActiveSpace(connection)

        self.currentSpaceID = spaceID
        self.currentSpaceIndex = getSpaceIndex(for: spaceID)
    }

    func getCurrentSpaceID() -> Int {
        let connection = Self.CGSDefaultConnectionForThread()
        return Self.CGSGetActiveSpace(connection)
    }

    /// 调试：打印所有空间信息
    func debugPrintSpaces() {
        let connection = Self.CGSDefaultConnectionForThread()
        let currentID = Self.CGSGetActiveSpace(connection)
        print("[SpaceManager] ========== 桌面空间调试 ==========")
        print("[SpaceManager] 当前活动 Space ID: \(currentID)")

        guard let displays = Self.CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            print("[SpaceManager] 错误: 无法获取桌面空间列表")
            return
        }

        var userSpaceIndex = 1
        for (displayIndex, display) in displays.enumerated() {
            print("[SpaceManager] Display \(displayIndex):")
            if let spaces = display["Spaces"] as? [[String: Any]] {
                for space in spaces {
                    // 尝试多种可能的 ID 键
                    let id64 = space["id64"] as? Int
                    let managedSpaceID = space["ManagedSpaceID"] as? Int
                    let type = space["type"] as? Int ?? -1
                    let uuid = (space["uuid"] as? String ?? "unknown").prefix(8)

                    let spaceIDValue = id64 ?? managedSpaceID ?? 0
                    let isCurrentSpace = spaceIDValue == currentID
                    let typeStr = type == 0 ? "用户桌面" : (type == 4 ? "全屏应用" : "type=\(type)")

                    if type == 0 {
                        print("  桌面 \(userSpaceIndex): id=\(spaceIDValue), \(typeStr), uuid=\(uuid)...\(isCurrentSpace ? " <-- 当前" : "")")
                        userSpaceIndex += 1
                    } else {
                        print("  [跳过]: id=\(spaceIDValue), \(typeStr), uuid=\(uuid)...")
                    }
                }
            }
        }
        print("[SpaceManager] ====================================")
    }

    /// 获取所有用户桌面空间（排除全屏应用）
    func getAllSpaces() -> [[String: Any]]? {
        let connection = Self.CGSDefaultConnectionForThread()
        guard let displays = Self.CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return nil
        }

        var allSpaces: [[String: Any]] = []
        for display in displays {
            if let spaces = display["Spaces"] as? [[String: Any]] {
                // 只包含用户桌面空间 (type == 0)，排除全屏应用空间 (type == 4)
                let userSpaces = spaces.filter { ($0["type"] as? Int) == 0 }
                allSpaces.append(contentsOf: userSpaces)
            }
        }
        return allSpaces
    }

    /// 根据 Space ID 获取空间索引（从1开始）
    func getSpaceIndex(for spaceID: Int) -> Int {
        guard let spaces = getAllSpaces() else { return 1 }

        for (index, space) in spaces.enumerated() {
            // 尝试 id64 键
            if let id = space["id64"] as? Int, id == spaceID {
                return index + 1
            }
            // 尝试 ManagedSpaceID 键
            if let id = space["ManagedSpaceID"] as? Int, id == spaceID {
                return index + 1
            }
        }

        // 如果在用户桌面中找不到，可能是全屏应用空间
        // 检查是否是全屏应用
        let connection = Self.CGSDefaultConnectionForThread()
        guard let displays = Self.CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return 1
        }

        for display in displays {
            if let spaces = display["Spaces"] as? [[String: Any]] {
                for space in spaces {
                    let id = space["id64"] as? Int ?? space["ManagedSpaceID"] as? Int ?? 0
                    let type = space["type"] as? Int ?? 0
                    if id == spaceID && type != 0 {
                        return 0  // 全屏应用空间返回 0
                    }
                }
            }
        }

        return 1
    }

    func getSpaceCount() -> Int {
        return getAllSpaces()?.count ?? 1
    }

    func getDefaultSpaceName(for spaceID: Int) -> String {
        let index = getSpaceIndex(for: spaceID)
        if index == 0 {
            return "全屏应用"
        }
        return "桌面 \(index)"
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
