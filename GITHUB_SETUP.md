# GitHub 上传和发布配置完成

## 📦 已完成的配置

### 1. .gitignore 文件
- ✅ 排除 Xcode 构建产物
- ✅ 排除用户设置文件
- ✅ 排除 macOS 系统文件（.DS_Store、._* 等）
- ✅ 排除临时文件和压缩包

### 2. GitHub Actions 自动发布流程
- ✅ 监听版本 tag（v*）
- ✅ 自动构建 macOS 应用
- ✅ 打包成 DMG 格式
- ✅ 创建 GitHub Release
- ✅ 自动上传 DMG 文件

### 3. 本地 DMG 打包脚本
- ✅ 创建 scripts/create_dmg.sh
- ✅ 支持自定义窗口和图标布局
- ✅ 包含 Applications 快捷方式

### 4. 项目文档
- ✅ 更新 README.md
- ✅ 添加发布流程说明
- ✅ 添加安装说明

## 🚀 使用指南

### 第一步：上传到 GitHub

```bash
# 1. 添加所有新文件和更改
git add .

# 2. 提交
git commit -m "chore: 配置 GitHub Actions 和 DMG 自动发布"

# 3. 添加远程仓库（如果还没添加）
git remote add origin https://github.com/zwmjohn-cool/pinnote.git

# 4. 推送到 GitHub
git push -u origin main
```

### 第二步：创建首个发布版本

```bash
# 1. 创建版本 tag
git tag v1.0.0

# 2. 推送 tag
git push origin v1.0.0
```

### 第三步：查看自动构建

1. 访问 https://github.com/zwmjohn-cool/pinnote/actions
2. 查看 "Release" workflow 的构建进度
3. 构建完成后，访问 https://github.com/zwmjohn-cool/pinnote/releases
4. 下载 `pinnote-macos.dmg` 进行测试

## 📝 后续版本发布流程

```bash
# 1. 开发和提交代码
git add .
git commit -m "feat: 添加新功能"
git push origin main

# 2. 创建新版本 tag
git tag v1.1.0

# 3. 推送 tag 触发自动发布
git push origin v1.1.0
```

## 💡 版本号建议

遵循语义化版本号（Semantic Versioning）：
- `v1.0.0` - 第一个正式版本
- `v1.1.0` - 添加新功能（向后兼容）
- `v1.0.1` - 修复 bug（向后兼容）
- `v2.0.0` - 重大更新（可能不向后兼容）
- `v1.0.0-beta.1` - 测试版本

## 🔧 本地测试 DMG 打包

如果你想在本地测试 DMG 打包（不通过 GitHub Actions）：

```bash
# 1. 使用 Xcode 构建
xcodebuild -project pinnote.xcodeproj \
  -scheme pinnote \
  -configuration Release \
  -derivedDataPath ./build

# 2. 创建 DMG
./scripts/create_dmg.sh ./build/Build/Products/Release/pinnote.app
```

## ⚠️ 注意事项

1. **代码签名**：当前配置使用未签名的构建，用户首次打开时需要右键选择"打开"
2. **公证**：如果需要分发给更多用户，建议配置 Apple Developer 账号进行代码签名和公证
3. **隐私权限**：确保在 Info.plist 中添加必要的权限描述

## 📚 相关文件

- [.gitignore](.gitignore) - Git 忽略规则
- [.github/workflows/release.yml](.github/workflows/release.yml) - GitHub Actions 配置
- [scripts/create_dmg.sh](scripts/create_dmg.sh) - 本地 DMG 打包脚本
- [README.md](README.md) - 项目说明文档

---

配置完成！现在你可以开始上传代码到 GitHub 了。
