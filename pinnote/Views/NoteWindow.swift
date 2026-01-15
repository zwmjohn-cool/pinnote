import SwiftUI
import AppKit

/// 便利贴主窗口视图
struct NoteWindow: View {
    @ObservedObject var viewModel: NoteViewModel
    @StateObject private var spaceManager = SpaceManager.shared
    @State private var isEditing = false
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏 - 显示桌面空间信息
            HeaderView(
                spaceName: viewModel.note.spaceName,
                spaceID: viewModel.note.spaceID,
                isHovering: isHovering,
                onClose: { viewModel.closeWindow() },
                onSpaceNameChange: { newName in
                    viewModel.updateSpaceName(newName)
                }
            )

            // 工具栏
            if isHovering || isEditing {
                ToolbarView(
                    onFormat: { command in
                        if let textView = NSApplication.shared.currentTextView {
                            command.apply(to: textView)
                        }
                    },
                    onColorChange: { hex in
                        viewModel.updateBackgroundColor(hex)
                    },
                    currentColor: viewModel.note.backgroundColor
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 富文本编辑器
            RichTextEditor(
                attributedText: $viewModel.attributedText,
                backgroundColor: viewModel.note.color,
                textColor: viewModel.note.nsTextColor
            )
            .frame(minWidth: 200, minHeight: 150)
        }
        .background(viewModel.note.color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onAppear {
            // 更新当前桌面空间
            let currentSpaceID = spaceManager.getCurrentSpaceID()
            if viewModel.note.spaceID == 0 {
                viewModel.updateSpaceID(currentSpaceID)
            }
        }
        .onReceive(spaceManager.$currentSpaceID) { newSpaceID in
            // 当切换桌面时，更新便利贴的桌面空间信息
            if newSpaceID != 0 && newSpaceID != viewModel.note.spaceID {
                viewModel.updateSpaceID(newSpaceID)
            }
        }
    }
}

// MARK: - 顶部标题栏
struct HeaderView: View {
    let spaceName: String
    let spaceID: Int
    let isHovering: Bool
    let onClose: () -> Void
    let onSpaceNameChange: (String) -> Void

    @State private var isEditingName = false
    @State private var editedName: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // 关闭按钮
            if isHovering {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            // 桌面空间标识
            if isEditingName {
                TextField("空间名称", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: 150)
                    .onSubmit {
                        onSpaceNameChange(editedName)
                        isEditingName = false
                    }
                    .onExitCommand {
                        isEditingName = false
                    }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 10))
                    Text(spaceName)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.black)
                .onTapGesture(count: 2) {
                    editedName = spaceName
                    isEditingName = true
                }
            }

            Spacer()

            // 新建便利贴按钮
            if isHovering {
                Button(action: {
                    NotificationCenter.default.post(name: .createNewNote, object: nil)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white)
    }
}

// MARK: - 预览
#Preview {
    NoteWindow(viewModel: NoteViewModel(note: Note()))
        .frame(width: 300, height: 300)
}
