import Foundation
import SwiftUI

/// 便利贴数据模型
struct Note: Identifiable, Codable {
    let id: UUID
    var content: Data  // RTF 格式存储富文本
    var spaceID: Int   // 桌面空间 ID
    var spaceName: String  // 用户自定义空间名称
    var backgroundColor: String  // 背景颜色 hex
    var windowX: Double
    var windowY: Double
    var windowWidth: Double
    var windowHeight: Double
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool  // 是否置于最后

    init(
        id: UUID = UUID(),
        content: Data = Data(),
        spaceID: Int = 0,
        spaceName: String = "桌面",
        backgroundColor: String = "#FFFFFF",  // 白色背景
        windowX: Double = 100,
        windowY: Double = 100,
        windowWidth: Double = 300,
        windowHeight: Double = 300,
        isPinned: Bool = false
    ) {
        self.id = id
        self.content = content
        self.spaceID = spaceID
        self.spaceName = spaceName
        self.backgroundColor = backgroundColor
        self.windowX = windowX
        self.windowY = windowY
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = isPinned
    }

    var windowFrame: CGRect {
        get {
            CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
        }
        set {
            windowX = newValue.origin.x
            windowY = newValue.origin.y
            windowWidth = newValue.size.width
            windowHeight = newValue.size.height
        }
    }

    var color: Color {
        Color(hex: backgroundColor) ?? .yellow
    }

    /// 文字颜色 - 始终使用黑色
    var textColor: Color {
        .black
    }

    var nsTextColor: NSColor {
        .black
    }

    mutating func updateContent(_ data: Data) {
        content = data
        updatedAt = Date()
    }
}

// MARK: - 预设背景颜色
extension Note {
    static let presetColors: [(name: String, hex: String)] = [
        ("柠檬黄", "#FFFACD"),
        ("薄荷绿", "#98FB98"),
        ("天空蓝", "#87CEEB"),
        ("樱花粉", "#FFB6C1"),
        ("淡紫色", "#E6E6FA"),
        ("橙色", "#FFDAB9"),
        ("白色", "#FFFFFF")
    ]
}

// MARK: - Color Hex 扩展
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
