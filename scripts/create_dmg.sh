#!/bin/bash

# DMG 创建脚本
# 用法: ./scripts/create_dmg.sh <app_path> <output_dmg_name>

set -e

APP_PATH=$1
DMG_NAME=${2:-"pinnote-macos.dmg"}
VOLUME_NAME="PinNote"
TEMP_DMG="temp.dmg"
STAGING_DIR="dmg_staging"

if [ -z "$APP_PATH" ]; then
    echo "错误: 请提供 .app 文件路径"
    echo "用法: $0 <app_path> [output_dmg_name]"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "错误: 找不到应用: $APP_PATH"
    exit 1
fi

echo "正在创建 DMG..."
echo "应用路径: $APP_PATH"
echo "输出文件: $DMG_NAME"

# 清理之前的构建
rm -rf "$STAGING_DIR"
rm -f "$DMG_NAME" "$TEMP_DMG"

# 创建临时目录
mkdir -p "$STAGING_DIR"

# 复制应用到临时目录
echo "复制应用..."
cp -R "$APP_PATH" "$STAGING_DIR/"

# 创建应用程序文件夹的符号链接
echo "创建 Applications 链接..."
ln -s /Applications "$STAGING_DIR/Applications"

# 创建临时 DMG
echo "创建临时 DMG..."
hdiutil create -srcfolder "$STAGING_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 200m \
    "$TEMP_DMG"

# 挂载临时 DMG
echo "挂载 DMG..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | grep "/Volumes/$VOLUME_NAME" | awk '{print $3}')

if [ -z "$MOUNT_DIR" ]; then
    echo "错误: 无法挂载 DMG"
    exit 1
fi

echo "已挂载到: $MOUNT_DIR"

# 设置 DMG 窗口属性
echo "设置 DMG 窗口属性..."
osascript <<EOT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 450}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set background picture of viewOptions to file ".background:background.png"

        -- 设置图标位置
        set position of item "pinnote.app" of container window to {150, 170}
        set position of item "Applications" of container window to {450, 170}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOT

# 等待设置完成
sleep 3

# 卸载临时 DMG
echo "卸载 DMG..."
hdiutil detach "$MOUNT_DIR"

# 转换为压缩的只读 DMG
echo "压缩 DMG..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_NAME"

# 清理临时文件
echo "清理临时文件..."
rm -f "$TEMP_DMG"
rm -rf "$STAGING_DIR"

echo "✅ DMG 创建成功: $DMG_NAME"
ls -lh "$DMG_NAME"
