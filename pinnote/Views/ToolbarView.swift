import SwiftUI
import AppKit

/// 格式化工具栏
struct ToolbarView: View {
    var onFormat: (TextFormatCommand) -> Void
    var onColorChange: (String) -> Void
    var currentColor: String

    @State private var showColorPicker = false

    var body: some View {
        HStack(spacing: 4) {
            // 格式化按钮组
            Group {
                FormatButton(icon: "bold", tooltip: "粗体 ⌘B") {
                    onFormat(.bold)
                }

                FormatButton(icon: "italic", tooltip: "斜体 ⌘I") {
                    onFormat(.italic)
                }

                FormatButton(icon: "underline", tooltip: "下划线 ⌘U") {
                    onFormat(.underline)
                }
            }

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

            // 字体大小按钮
            Group {
                FormatButton(icon: "textformat.size.smaller", tooltip: "减小字号") {
                    onFormat(.decreaseFontSize)
                }

                FormatButton(icon: "textformat.size.larger", tooltip: "增大字号") {
                    onFormat(.increaseFontSize)
                }
            }

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

            // 颜色选择器
            ColorPickerButton(
                currentColor: currentColor,
                showPicker: $showColorPicker,
                onColorChange: onColorChange
            )

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.9))
    }
}

// MARK: - 格式化按钮
struct FormatButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(tooltip)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - 颜色选择器按钮
struct ColorPickerButton: View {
    let currentColor: String
    @Binding var showPicker: Bool
    let onColorChange: (String) -> Void

    var body: some View {
        Menu {
            ForEach(Note.presetColors, id: \.hex) { color in
                Button(action: { onColorChange(color.hex) }) {
                    HStack {
                        Circle()
                            .fill(Color(hex: color.hex) ?? .white)
                            .frame(width: 12, height: 12)
                        Text(color.name)
                        if color.hex == currentColor {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Circle()
                .fill(Color(hex: currentColor) ?? .white)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
        .frame(width: 24, height: 24)
        .help("更换背景颜色")
    }
}

// MARK: - 预览
#Preview {
    ToolbarView(
        onFormat: { _ in },
        onColorChange: { _ in },
        currentColor: "#FFFFFF"
    )
    .frame(width: 300)
}
