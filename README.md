# PinNote

一个 macOS 桌面便利贴应用，支持多桌面同步和菜单栏快速访问。

## 功能特性

- 创建和管理桌面便利贴
- 支持多桌面同步
- 菜单栏快速访问
- 自动保存便利贴内容
- 自定义菜单栏图标
- 便利贴跨桌面拖动

## 开发环境

- macOS
- Xcode
- Swift

## 构建说明

1. 克隆项目
```bash
git clone https://github.com/zwmjohn-cool/pinnote.git
cd pinnote
```

2. 使用 Xcode 打开项目
```bash
open pinnote.xcodeproj
```

3. 在 Xcode 中选择目标设备并运行

## 发布流程

项目配置了 GitHub Actions 自动发布流程，当你推送带有版本号的 tag 时，会自动构建并发布应用。

### 创建新版本发布

1. 提交你的更改
```bash
git add .
git commit -m "你的提交信息"
```

2. 创建版本 tag（例如 v1.0.0）
```bash
git tag v1.0.0
```

3. 推送代码和 tag 到 GitHub
```bash
git push origin main
git push origin v1.0.0
```

4. GitHub Actions 会自动：
   - 构建应用
   - 打包成 DMG 格式
   - 创建 Release
   - 上传 `pinnote-macos.dmg` 到 Release

### 版本号规范

建议使用语义化版本号（Semantic Versioning）：
- `v1.0.0` - 主版本.次版本.补丁版本
- `v1.0.0-beta.1` - 预发布版本

## 安装说明

从 [Releases](https://github.com/zwmjohn-cool/pinnote/releases) 页面下载最新版本：

1. 下载 `pinnote-macos.dmg`
2. 双击打开 DMG 文件
3. 将 `pinnote.app` 拖到 `Applications` 文件夹
4. 首次打开时，右键点击应用选择"打开"（绕过 macOS 的安全限制）

## 本地构建 DMG

如果你想在本地构建 DMG，可以使用提供的脚本：

```bash
# 首先在 Xcode 中构建应用，或使用命令行
xcodebuild -project pinnote.xcodeproj \
  -scheme pinnote \
  -configuration Release \
  -derivedDataPath ./build

# 然后使用脚本创建 DMG
./scripts/create_dmg.sh ./build/Build/Products/Release/pinnote.app
```

## 许可证

[添加你的许可证信息]
