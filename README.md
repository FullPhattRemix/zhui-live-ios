# 追帧Live iOS 仿制版（SwiftUI · iOS 云母材质 · 免登录）

与安卓版功能对齐的 iOS 实现：粘贴分享文本（快速粘贴提取纯链接）、▶播放/■停止/只听声音、
追帧模式（智能 1.01x~2x / 固定档）、实时缓存、通知音量开关、全屏内速度胶囊调档。

## 工程

```
ZhuiLiveIOS/
├── project.yml                     # XcodeGen 工程定义
├── Podfile                         # MobileVLCKit（HTTP-FLV 播放内核）
├── .github/workflows/build-ios.yml # 推送即自动出未签名 IPA（macOS 云构建）
└── ZhuiLive/
    ├── ZhuiLiveApp.swift           # 入口
    ├── ContentView.swift           # 云母 UI（ultraThinMaterial 卡片 + iOS 蓝）+ 全屏覆盖层
    ├── PlayerController.swift      # VLC 播放控制 + 状态轮询 + 云端兜底 + 快速粘贴
    ├── PlayerContainerView.swift   # VLC drawable 承载
    ├── ChaseController.swift       # 追帧状态机（与安卓同参数移植）
    └── StreamResolver.swift        # 直链规则（小红书 _orig 重写）+ 设备码 + 云端 resolve
```

## 出包方式（Windows 无法签名 IPA，三选一）

1. **GitHub Actions（推荐，无需 Mac）**：把本目录推到 GitHub 仓库，Actions 自动构建，
   在 Artifacts 下载 `ZhuiLive-unsigned.ipa`。
2. **本地 Mac**：`xcodegen generate && pod install`，打开 `ZhuiLive.xcworkspace`，
   选真机 Run。
3. **免签名安装**：未签名 IPA 可用 TrollStore 直接装；或 AltStore/Sideloadly 用个人
   Apple ID 重签（7 天有效期）。

## 与安卓版的差异（如实说明）

| 项 | 安卓 | iOS |
|---|---|---|
| 播放内核 | libmpv（原 APK 提取） | MobileVLCKit（CocoaPods） |
| 分享短链解析 | 隐藏 WebView 优选（UA 伪装 + .flv 拦截） | 直接走云端 stream/resolve（等价兜底，Apple 对页面注入限制更严） |
| 通知音量 | PCM FIFO→AudioTrack（真·通知流） | iOS 无独立通知音量流，映射为 .ambient（跟随静音键）/ .playback |
| 追帧缓存估计 | mpv demuxer-cache-duration（精确） | VLC 无该属性，用播放推进 vs 墙钟差估计（近似） |
| 设备码 | ANDROID- + SHA256(android_id)[:8] | IOS- + SHA256(idf_vendor)[:8]（后端同构识别） |

## 后端

与安卓版共用同一替代后端（`../mock-backend`），接口规格见 `../分析报告-追帧Live工作原理.md`。
免登录版 App 不强制 license/check；cloudResolve 在本地解析失败时调用。
