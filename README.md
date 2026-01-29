# PinNote

一个 macOS 桌面便利贴应用，支持识别桌面ID和菜单栏快速访问。

## 安装说明

从 [Releases](https://github.com/zwmjohn-cool/pinnote/releases) 页面下载最新版本：

1. 下载 `pinnote-macos.dmg`
2. 双击打开 DMG 文件
3. 将 `pinnote.app` 拖到 `Applications` 文件夹
4. 首次打开时，右键点击应用选择"打开"（绕过 macOS 的安全限制）

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

MIT License

Copyright (c) 2026 zwmjohn-cool

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
