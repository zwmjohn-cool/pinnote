import Foundation
import CoreGraphics

enum AppSettings {
    static let defaultNoteWidthKey = "default_note_width"
    static let defaultNoteHeightKey = "default_note_height"

    static let minNoteWidth: Double = 200
    static let maxNoteWidth: Double = 1200
    static let minNoteHeight: Double = 200
    static let maxNoteHeight: Double = 1200

    static let fallbackNoteWidth: Double = 300
    static let fallbackNoteHeight: Double = 300

    private static let userDefaults = UserDefaults.standard

    static var defaultNoteWidth: Double {
        let value = userDefaults.double(forKey: defaultNoteWidthKey)
        return clampedWidth(value == 0 ? fallbackNoteWidth : value)
    }

    static var defaultNoteHeight: Double {
        let value = userDefaults.double(forKey: defaultNoteHeightKey)
        return clampedHeight(value == 0 ? fallbackNoteHeight : value)
    }

    static var defaultNoteSize: CGSize {
        CGSize(width: defaultNoteWidth, height: defaultNoteHeight)
    }

    static func clampedWidth(_ width: Double) -> Double {
        min(max(width, minNoteWidth), maxNoteWidth)
    }

    static func clampedHeight(_ height: Double) -> Double {
        min(max(height, minNoteHeight), maxNoteHeight)
    }
}
