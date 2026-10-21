# 时序

An iPhone SwiftUI MVP for daily tasks, time logging, and a gentle plan-vs-actual review.

## Run

Open `Rhythm.xcodeproj` in Xcode 15 or later, select an iPhone simulator or device, then run the `Rhythm` target. The deployment target is iOS 17.

## Included

- Today list with user-managed categories (add, rename, recolor, delete), subtasks, and count-based progress.
- Tomorrow's top-three list.
- Two 24-hour clock dials on the home screen: planned blocks vs actual logging, with red slices for plan deviations.
- Tap a slice to see and edit "what happens between which times"; tap empty dial space to log that time directly.
- Daily review listing missed, delayed, overlong, partial, and unplanned blocks, each with planned vs actual time ranges.
- Local persistence with SwiftData.
- Siri/App Shortcuts quick capture with an automatic timestamp.

Lock-screen widgets are not included in this MVP; a WidgetKit extension target and shared data configuration still need to be added in Xcode.

## 生成安装包（IPA）

iOS 应用只能在 macOS 上编译，因此有两种方式：

### 方式 A：GitHub Actions 自动构建（无需 Mac）

1. 把这个目录推送到 GitHub 仓库的 `main` 分支。
2. 打开仓库的 **Actions → Build unsigned IPA → Run workflow**。
3. 构建完成后在运行记录页下载 `Rhythm-unsigned-ipa` 里的 `Rhythm-unsigned.ipa`。

该产物是**未签名**的，不能直接安装。用 Sideloadly / AltStore 等工具，配合你自己的 Apple ID 重新签名后安装到 iPhone（免费账号签名的应用 7 天后需重签）。

### 方式 B：Mac + Xcode（推荐）

1. 用 Xcode 15+ 打开 `Rhythm.xcodeproj`。
2. 在 target 的 Signing & Capabilities 里选择你的个人 Team，把 Bundle Identifier 改成唯一值。
3. 连接 iPhone，运行一次以完成免费签名安装。

### 本地命令行打包

```bash
chmod +x scripts/build-ipa.sh
./scripts/build-ipa.sh
```

输出 `build/Rhythm-unsigned.ipa`，同样需要重新签名才能安装。

