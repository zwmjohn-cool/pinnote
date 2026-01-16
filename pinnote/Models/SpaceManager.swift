import Foundation
import AppKit

// MARK: - 显示器信息
struct DisplayInfo {
    let identifier: String      // 显示器标识符
    let isMain: Bool           // 是否主屏
    let displayIndex: Int      // 显示器索引（主屏=0，副屏从1开始）

    var displayName: String {
        if isMain {
            return "主屏"
        } else {
            return "副屏\(displayIndex)"
        }
    }
}

// MARK: - 桌面空间信息
struct SpaceInfo {
    let spaceID: Int
    let display: DisplayInfo
    let spaceIndex: Int        // 在该显示器上的桌面索引（从1开始）

    var fullName: String {
        return "\(display.displayName) 桌面 \(spaceIndex)"
    }
}

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
            if let info = self.getSpaceInfo(for: self.currentSpaceID) {
                print("[SpaceManager] 桌面切换 -> \(info.fullName) (ID: \(self.currentSpaceID))")
            } else {
                print("[SpaceManager] 桌面切换 -> Space ID: \(self.currentSpaceID)")
            }
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

    // MARK: - 获取显示器信息

    /// 解析所有显示器及其桌面空间
    private func parseDisplaysAndSpaces() -> [(display: DisplayInfo, spaces: [[String: Any]])]? {
        let connection = Self.CGSDefaultConnectionForThread()
        guard let displays = Self.CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return nil
        }

        var result: [(display: DisplayInfo, spaces: [[String: Any]])] = []
        var secondaryIndex = 1  // 副屏编号从1开始

        for (index, display) in displays.enumerated() {
            let identifier = display["Display Identifier"] as? String ?? "unknown-\(index)"

            // 判断是否主屏：第一个显示器通常是主屏，或者标识符包含 "Main"
            let isMain = index == 0 || identifier.lowercased().contains("main")

            let displayInfo = DisplayInfo(
                identifier: identifier,
                isMain: isMain,
                displayIndex: isMain ? 0 : secondaryIndex
            )

            if !isMain {
                secondaryIndex += 1
            }

            // 获取该显示器的桌面空间（只包含用户桌面，排除全屏应用）
            if let spaces = display["Spaces"] as? [[String: Any]] {
                let userSpaces = spaces.filter { ($0["type"] as? Int) == 0 }
                result.append((display: displayInfo, spaces: userSpaces))
            }
        }

        return result
    }

    /// 获取指定 spaceID 的详细信息
    func getSpaceInfo(for spaceID: Int) -> SpaceInfo? {
        guard let displaysAndSpaces = parseDisplaysAndSpaces() else {
            return nil
        }

        for (displayInfo, spaces) in displaysAndSpaces {
            for (index, space) in spaces.enumerated() {
                let id = space["id64"] as? Int ?? space["ManagedSpaceID"] as? Int ?? 0
                if id == spaceID {
                    return SpaceInfo(
                        spaceID: spaceID,
                        display: displayInfo,
                        spaceIndex: index + 1
                    )
                }
            }
        }

        // 检查是否是全屏应用空间
        let connection = Self.CGSDefaultConnectionForThread()
        guard let displays = Self.CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return nil
        }

        for display in displays {
            if let spaces = display["Spaces"] as? [[String: Any]] {
                for space in spaces {
                    let id = space["id64"] as? Int ?? space["ManagedSpaceID"] as? Int ?? 0
                    let type = space["type"] as? Int ?? 0
                    if id == spaceID && type != 0 {
                        // 全屏应用空间
                        return nil
                    }
                }
            }
        }

        return nil
    }

    /// 调试：打印所有空间信息
    func debugPrintSpaces() {
        let connection = Self.CGSDefaultConnectionForThread()
        let currentID = Self.CGSGetActiveSpace(connection)
        print("[SpaceManager] ========== 桌面空间调试 ==========")
        print("[SpaceManager] 当前活动 Space ID: \(currentID)")

        guard let displaysAndSpaces = parseDisplaysAndSpaces() else {
            print("[SpaceManager] 错误: 无法获取桌面空间列表")
            return
        }

        for (displayInfo, spaces) in displaysAndSpaces {
            print("[SpaceManager] \(displayInfo.displayName) (identifier: \(displayInfo.identifier.prefix(20))...):")
            for (index, space) in spaces.enumerated() {
                let id = space["id64"] as? Int ?? space["ManagedSpaceID"] as? Int ?? 0
                let uuid = (space["uuid"] as? String ?? "unknown").prefix(8)
                let isCurrentSpace = id == currentID
                print("  桌面 \(index + 1): id=\(id), uuid=\(uuid)...\(isCurrentSpace ? " <-- 当前" : "")")
            }
        }
        print("[SpaceManager] ====================================")
    }

    /// 获取所有用户桌面空间（排除全屏应用）
    func getAllSpaces() -> [[String: Any]]? {
        guard let displaysAndSpaces = parseDisplaysAndSpaces() else {
            return nil
        }

        var allSpaces: [[String: Any]] = []
        for (_, spaces) in displaysAndSpaces {
            allSpaces.append(contentsOf: spaces)
        }
        return allSpaces
    }

    /// 根据 Space ID 获取空间索引（全局索引，从1开始）
    func getSpaceIndex(for spaceID: Int) -> Int {
        if let info = getSpaceInfo(for: spaceID) {
            return info.spaceIndex
        }
        return 1
    }

    func getSpaceCount() -> Int {
        return getAllSpaces()?.count ?? 1
    }

    /// 生成默认的空间名称，格式：主屏 桌面 1 / 副屏1 桌面 2
    func getDefaultSpaceName(for spaceID: Int) -> String {
        if let info = getSpaceInfo(for: spaceID) {
            return info.fullName
        }

        // 检查是否是全屏应用
        let connection = Self.CGSDefaultConnectionForThread()
        guard let displays = Self.CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return "桌面"
        }

        for display in displays {
            if let spaces = display["Spaces"] as? [[String: Any]] {
                for space in spaces {
                    let id = space["id64"] as? Int ?? space["ManagedSpaceID"] as? Int ?? 0
                    let type = space["type"] as? Int ?? 0
                    if id == spaceID && type != 0 {
                        return "全屏应用"
                    }
                }
            }
        }

        return "桌面"
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
