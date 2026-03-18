import SwiftUI
import AppKit

/// 富文本编辑器 - 封装 NSTextView
struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var isEditing: Bool
    var backgroundColor: Color
    var textColor: NSColor
    var topInset: CGFloat = 8

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )

        textContainer.widthTracksTextView = true
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let textView = PinNoteTextView(frame: .zero, textContainer: textContainer)
        textView.onFocusChange = { isFocused in
            context.coordinator.updateEditingState(isFocused)
        }
        textView.requestInitialFocus = { [weak textView] in
            guard let textView else { return }
            context.coordinator.requestInitialFocus(for: textView)
        }
        scrollView.documentView = textView

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
        textView.focusRingType = NSFocusRingType.none
        textView.minSize = NSSize.zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = NSView.AutoresizingMask.width
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true

        // 设置默认字体和颜色
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = textColor

        // 透明背景
        textView.drawsBackground = false

        // 边距
        textView.textContainerInset = NSSize(width: 8, height: topInset)

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
        textView.textContainerInset = NSSize(width: 8, height: topInset)

        // 只在内容实际变化时更新，避免光标跳动
        if !context.coordinator.isEditing {
            let currentText = textView.attributedString()
            if !currentText.isEqual(to: attributedText) {
                let selectedRanges = textView.selectedRanges
                textView.textStorage?.setAttributedString(attributedText)
                textView.selectedRanges = selectedRanges
            }
        }

        context.coordinator.requestInitialFocus(for: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var isEditing = false
        private var didRequestInitialFocus = false

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func updateEditingState(_ isEditing: Bool) {
            guard self.isEditing != isEditing else { return }
            self.isEditing = isEditing
            DispatchQueue.main.async {
                self.parent.isEditing = isEditing
            }
        }

        func requestInitialFocus(for textView: NSTextView) {
            guard !didRequestInitialFocus,
                  let window = textView.window else {
                return
            }

            didRequestInitialFocus = true
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(textView)
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            updateEditingState(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            updateEditingState(false)
            guard let textView = notification.object as? NSTextView else { return }
            parent.attributedText = textView.attributedString()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.attributedText = textView.attributedString()
        }
    }
}

private final class PinNoteTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?
    var requestInitialFocus: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestInitialFocus?()
    }

    override func mouseDown(with event: NSEvent) {
        if let window {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }

        super.mouseDown(with: event)

        if window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            onFocusChange?(true)
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            onFocusChange?(false)
        }
        return didResignFirstResponder
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
