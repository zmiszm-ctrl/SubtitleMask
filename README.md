# Subtitle Mask（字幕遮挡条）

这是一个简单的工具类产品：看剧/看视频时，用一个**永远置顶**的可伸缩遮挡条遮住中文字幕/本土字幕，保留英文字幕，便于练习英语。

## 现阶段（Mac）

已提供一个最小可用的 macOS 版本（Swift + AppKit/SwiftUI），满足：

- 永远置顶（Floating level）
- 可拖拽移动、可自由缩放窗口大小（最小高度支持到 `10px`）
- 支持切换遮挡图案（开发时读取 `subtitle tool/image/`，安装包内置到应用资源目录）
- 支持调节透明度与圆角
- 提供独立悬浮按钮（不覆盖遮挡条），点击展开设置面板和操作说明
- 控制面板包含 `图案文件夹` 按钮，可一键打开当前应用内部的图案资源目录进行替换
- 控制面板包含 `关闭程序` 按钮（等价于 `⌘ + Q`）
- 悬浮按钮支持贴边吸附，窗口位置和参数会自动记忆

## 运行方式（Mac）

在仓库根目录执行：

```bash
cd "subtitle tool/subtitle-mask-mac"
swift build
./.build/debug/subtitle-mask
```

如果你想指定图案资源目录，可传环境变量：

```bash
SUBTITLE_MASK_ASSETS="/absolute/path/to/image" ./.build/debug/subtitle-mask
```

## 快捷键

- `⌘ + ⇧ + ]`：下一个图案
- `⌘ + ⇧ + [`：上一个图案
- 点击独立悬浮按钮：显示/隐藏控制面板

## 停止应用（关闭程序）

- 在控制面板中点击 `关闭程序` 按钮
- 或使用系统快捷键 `⌘ + Q`
- 如果是在终端前台运行（执行了 `./.build/debug/subtitle-mask`），可在该终端按 `Ctrl + C` 停止

如果程序在后台残留，可用以下命令结束进程：

```bash
pkill -f subtitle-mask
```

查看是否仍有进程：

```bash
ps aux | rg subtitle-mask
```

## 打包 DMG（含应用图标与背景美化）

项目已集成：

- 应用图标：读取 `subtitle tool/icon.png` 并自动生成 `.icns`
- DMG 背景：使用 `icon.png` 作为安装窗口背景图
- 安装布局：`SubtitleMask.app` + `Applications` 拖拽安装布局
- 图案资源预置：自动把 `subtitle tool/image/` 打包到 `SubtitleMask.app/Contents/Resources/image`

打包命令：

```bash
cd "subtitle tool/subtitle-mask-mac"
./scripts/build_dmg.sh
```

打包产物：

- `subtitle tool/subtitle-mask-mac/SubtitleMask-1.0.0.dmg`

脚本说明：

- `scripts/make_icns.sh`：把 `icon.png` 转换为 macOS 应用图标
- `scripts/build_dmg.sh`：编译 release、生成 `.app`、美化 DMG、导出可分发安装包

