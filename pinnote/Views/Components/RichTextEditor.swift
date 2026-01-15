import SwiftUI
import AppKit

/// 富文本编辑器 - 封装 NSTextView
struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var backgroundColor: Color
    var textColor: NSColor

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // 配置文本视图
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = true
        textView.usesRuler = false
        textView.importsGraphics = false
        textView.allowsImageEditing = false

        // 设置默认字体和颜色
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = textColor

        // 透明背景
        textView.drawsBackground = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        // 边距
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // 设置插入点（光标）颜色
        textView.insertionPointColor = textColor

        // 初始内容
        if attributedText.length > 0 {
            textView.textStorage?.setAttributedString(attributedText)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // 更新文字颜色
        textView.textColor = textColor
        textView.insertionPointColor = textColor

        // 只在内容实际变化时更新，避免光标跳动
        if !context.coordinator.isEditing {
            let currentText = textView.attributedString()
            if !currentText.isEqual(to: attributedText) {
                let selectedRanges = textView.selectedRanges
                textView.textStorage?.setAttributedString(attributedText)
                textView.selectedRanges = selectedRanges
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var isEditing = false

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            guard let textView = notification.object as? NSTextView else { return }
            parent.attributedText = textView.attributedString()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.attributedText = textView.attributedString()
        }
    }
}

// MARK: - 文本格式化命令
enum TextFormatCommand {
    case bold
    case italic
    case underline
    case increaseFontSize
    case decreaseFontSize

    func apply(to textView: NSTextView) {
        let range = textView.selectedRange()
        guard range.length > 0, let textStorage = textView.textStorage else { return }

        textStorage.beginEditing()

        switch self {
        case .bold:
            toggleTrait(.boldFontMask, in: textStorage, range: range)
        case .italic:
            toggleTrait(.italicFontMask, in: textStorage, range: range)
        case .underline:
            toggleUnderline(in: textStorage, range: range)
        case .increaseFontSize:
            changeFontSize(by: 2, in: textStorage, range: range)
        case .decreaseFontSize:
            changeFontSize(by: -2, in: textStorage, range: range)
        }

        textStorage.endEditing()
    }

    private func toggleTrait(_ trait: NSFontTraitMask, in storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            let fontManager = NSFontManager.shared
            let newFont: NSFont

            if fontManager.traits(of: font).contains(trait) {
                newFont = fontManager.convert(font, toNotHaveTrait: trait)
            } else {
                newFont = fontManager.convert(font, toHaveTrait: trait)
            }
            storage.addAttribute(.font, value: newFont, range: attrRange)
        }
    }

    private func toggleUnderline(in storage: NSTextStorage, range: NSRange) {
        var hasUnderline = false
        storage.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
            if let style = value as? Int, style != 0 {
                hasUnderline = true
                stop.pointee = true
            }
        }

        let newStyle = hasUnderline ? 0 : NSUnderlineStyle.single.rawValue
        storage.addAttribute(.underlineStyle, value: newStyle, range: range)
    }

    private func changeFontSize(by delta: CGFloat, in storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            let newSize = max(8, min(72, font.pointSize + delta))
            let newFont = NSFont(descriptor: font.fontDescriptor, size: newSize) ?? font
            storage.addAttribute(.font, value: newFont, range: attrRange)
        }
    }
}

// MARK: - 获取当前焦点的 NSTextView
extension NSApplication {
    var currentTextView: NSTextView? {
        keyWindow?.firstResponder as? NSTextView
    }
}
