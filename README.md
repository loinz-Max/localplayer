# 本地播放器（LocalPlayer）

一个人的 iOS 本地视频播放器。SwiftUI + AVPlayer，**零第三方依赖**。

视频只存在 App 的 `Documents` 目录里，不联网、不登录、不上传任何服务器。

- 仓库：<https://github.com/loinz-Max/localplayer>（public）
- **第一次接手先读 `HANDOVER.md`**：进度、权限、待办、踩过的坑都在里面
- 界面原型（设计唯一真相）：`preview/ui-v3.html`（资料库）+ `preview/ui-v5-player.html`（播放页），直接双击用浏览器打开；都支持 `?only=` 单屏查看
- 设计说明：`DESIGN.md`
- 规模：22 个 Swift 文件，约 3600 行；部署目标 iOS 17.0

---

## 一、它现在是什么样

**资料库页**：近黑背景（`#0A0A0B`）+ 自定义四层玻璃控件；顶栏四个 36pt 圆键（设置 / 导入 / 更多）+ 居中标题；双列网格，文件夹卡片排在视频前面；卡片是 16:9 缩略图 + 单行标题 + `时长 · 体积`；长按弹出锚定卡片的玻璃菜单（标记已看 / 重命名 / 删除）。

**播放页**：点屏唤出控件，按设置的时长淡出、暂停常驻。页面只有五样东西——左上关闭、右上列表、正中三圆（−10 / 播放 / +10，等大 58–62pt）、底部通栏进度条（时间文字在胶囊两端）、右下倍速键（点开是 110 宽的窄浮层，五档直选）。播放列表是右侧抽屉，展开时整层控件收起。原来的「播放设置抽屉」已取消，三项设置并进 App 设置页。

**能看图的三种方式**

| 方式 | 真实性 | 成本 |
|---|---|---|
| `preview/ui-v3.html` 静态原型 | 布局与配色还原，不能播视频 | 0 |
| GitHub Actions 自动截图（`ci-shots` 分支） | **真实编译 + 真实 SwiftUI 渲染** | 0 |
| 云 Mac / 本机 Xcode | 完全真实，可打断点改代码 | $0.99 起 |

在线截图：<https://github.com/loinz-Max/localplayer/tree/ci-shots>（每次构建自动覆盖）

---

## 二、功能范围

**导入**
- 文件 App：系统选择器，可多选，能选 SMB / 网盘挂载目录
- 相册：PhotosPicker 多选，文件名 `20261111_001.mov`
- 访达 / iTunes 文件共享直接拖进 Documents（`UIFileSharingEnabled` 已开）
- 重名自动追加 ` (2)`，不覆盖

**资料库**
- 文件夹浏览（面包屑返回）、新建文件夹
- 文件夹长按：重命名（**只改显示名**，磁盘目录名不变）、删除文件夹（连里面的视频一起删，有确认）
- 排序四选一：最近播放 / 名称 / 添加日期 / 文件大小，可切升降序
- 视频长按菜单：标记已看（或取消）、重命名（**真改磁盘文件名**，进度与已看标记随之迁移）、移到文件夹、删除
- 刷新缩略图、空状态引导

**播放**
- 断点续播（尾部 `min(15 秒, 总长 25%)` 视为看完并清进度）
- 播放模式：列表循环 / 单集循环 / 播完暂停
- 倍速五档 0.5 / 1 / 1.25 / 1.5 / 2，右下角浮层直选；倍速与模式**只在本次播放有效**，退出播放页即恢复默认
- 画面比例：适应 / 填充 / 拉伸（起始值取设置里的「默认画面」）
- 控件自动隐藏 2 / 4 / 6 秒、屏幕常亮、启动时锁定，三项都在设置页「播放界面」分组
- **防误触**：设置里开了「启动时锁定」后进播放页即锁，长按画面 1 秒解除；锁定时单击/双击/滑动一律不响应
- 手势：横滑调进度（跟手 + HUD 目标时间）、左半屏竖滑亮度、右半屏竖滑音量、长按 2× 快进（松手恢复）、双击左右 ±10 秒、双指捏合切画面比例
- 后台播放 / 锁屏继续出声

**设置页**：默认倍速（五档）、默认播放模式、默认画面、断点续播 ｜ 播放界面（屏幕常亮 / 控件自动隐藏 / 启动时锁定）｜ 视频占用与数量、清理缩略图缓存 ｜ 版本与隐私说明。

> 已明确不做：画中画、音轨切换、字幕、搜索、局域网传输、海报墙。

---

## 三、怎么跑起来

### 方式 A：本机 Mac（改一次看一次）

```bash
brew install xcodegen          # 只需一次
cd LocalPlayer
xcodegen generate
open LocalPlayer.xcodeproj     # 选自己的 iPhone，⌘R
```

或者一条命令编译 + 装进模拟器 + 带示例视频启动：

```bash
bash scripts/dev.sh
```

`project.yml` 是工程描述文件，**增删文件后要重新 `xcodegen generate`**。

真机安装：Target → Signing & Capabilities 填自己的 Team（免费 Apple ID 也行），把 `PRODUCT_BUNDLE_IDENTIFIER` 改成唯一值（如 `com.你的名字.localplayer`）。

### 方式 B：没有 Mac，用 GitHub 编译（当前使用的方式）

推送 `main` 自动触发（也可在 Actions 页手动 Run workflow），两个 job：

| job | 产出 |
|---|---|
| 模拟器截图 | `simulator-screenshots`（6 张 PNG）、`xcodebuild-log`，并推送到 `ci-shots` 分支 |
| 打包未签名 ipa | `LocalPlayer-unsigned-ipa` |

装机流程：

1. Actions → 最近一次 run → 底部 Artifacts 下载 `LocalPlayer-unsigned-ipa`
2. Windows 装 [Sideloadly](https://sideloadly.io)，数据线连 iPhone，把 ipa 拖进窗口，填 Apple ID，Start
3. 首次要在 iPhone「设置 → 通用 → VPN 与设备管理」里信任证书；iOS 16+ 还要开「开发者模式」并重启
4. 免费证书 **7 天**有效，到期用 Sideloadly 覆盖安装一次，或装 AltStore / SideStore 自动续签

**这个方式的天花板**（提前讲清）：免费账号同时最多 3 个自签名 App；删掉 App 再装，`Documents` 里的视频**会一起没**，重要片子先在「文件」App 里留一份。

**新仓库第一次跑之前**：Settings → Actions → General → **Workflow permissions 选 Read and write**，否则「把截图推到 ci-shots」那步会失败（不影响编译，只是看不到图）。

### 方式 C：租云 Mac

想自己拖界面、打断点，就必须有 macOS。MacinCloud 首单 $0.99/24 小时，Scaleway Mac mini €0.11/小时起。传上整个目录后跑 `bash scripts/dev.sh` 即可。

---

## 四、目录结构

```
LocalPlayer/
├─ project.yml                      XcodeGen 工程描述（部署目标 iOS 17.0）
├─ Info.plist                       相册读/写用途说明、文件共享、后台音频
├─ .github/workflows/ios-ipa.yml    云端编译 + 模拟器截图 + 失败取错误
├─ preview/ui-v3.html               ★ 界面原型（10 屏，唯一的设计真相）
├─ preview/shots/                   原型效果图（非真实截图）
├─ scripts/dev.sh                   本地一键：生成工程 → 编译 → 装机 → 带数据启动
├─ scripts/push-api.js              git 被代理挡住时，改用 Git Data API 推送
└─ LocalPlayer/
   ├─ App/LocalPlayerApp.swift      入口，注入三个 store，配 AVAudioSession
   ├─ Models/VideoItem.swift        VideoItem / SortKey / PlayMode
   ├─ Player/
   │  ├─ PlayerModel.swift          AVPlayer 封装：时间轴 / 倍速 / 缓冲 / 失败态
   │  └─ VideoSurface.swift         AVPlayerLayer 的 SwiftUI 包装
   ├─ Services/
   │  ├─ AppSettings.swift          默认倍速 / 模式 / 排序 / 续播（键名集中在此）
   │  ├─ LibraryStore.swift         扫描、导入、删除、重命名、建文件夹
   │  ├─ ProgressStore.swift        进度 + 最近播放顺序 + 已看标记
   │  ├─ ThumbnailLoader.swift      缩略图与时长缓存（NSCache + 并发去重）
   │  └─ PhotoImporter.swift        相册导入，「日期_流水号」命名
   ├─ Support/
   │  ├─ Palette.swift              色板（与 ui-v3.html 的 :root 一一对应）
   │  ├─ Glass.swift                ★ 四层玻璃配方 + 圆键
   │  ├─ FrameGrabber.swift         抓帧存相册
   │  ├─ Formatters.swift           体积 / 时间格式化、重名去重
   │  ├─ ScreenBrightness.swift     屏幕亮度
   │  ├─ SystemVolume.swift         系统音量（隐藏 MPVolumeView）
   │  └─ DebugSeed.swift            仅 Debug：生成示例视频
   └─ Views/
      ├─ LibraryView.swift          资料库页（网格 + 长按 + 弹窗 + 导入）
      ├─ LibraryMenus.swift         导入菜单 / 更多菜单 / 长按菜单
      ├─ Cards.swift                视频卡片 / 文件夹卡片 / 角标 / 缩略图
      ├─ PlayerScreen.swift         播放页（顶栏 + 三圆 + 进度条 + 倍速浮层 + 手势）
      ├─ PlayerPanels.swift         播放列表抽屉 / 倍速面板
      └─ SettingsView.swift         设置页
```

---

## 五、调试启动参数（仅 Debug 生效）

写在 `Support/DebugSeed.swift`，用 `xcrun simctl launch <udid> <bundle-id> <参数>` 传：

| 参数 | 作用 |
|---|---|
| `-screen home\|folder\|player\|settings\|empty` | 启动后直达某一屏 |
| `-screen foldermenu` | 直达首页并弹出第一个文件夹的长按菜单 |
| `-screen move` | 直达首页并弹出「移到文件夹」弹窗 |
| `-panel queue\|speed\|lock` | 进播放页后直接展开列表抽屉 / 倍速面板 / 锁定态（截图用） |
| `-seedDemo 1` | 现场生成 8 段 8 秒示例视频（4 段在「示例视频」文件夹，4 段在根目录） |
| `-keepChrome 1` | 钉住播放控制栏，否则 4 秒后自动隐藏，截图拍不到 |
| `-landscape 1` | 调 `requestGeometryUpdate` 真的把 App 转到横屏 |

> 注意：模拟器 `simctl io screenshot` 只拍竖屏 buffer，横屏截图里控件会是侧躺的，这是截屏方式的问题，不是布局问题。

---

## 六、数据与状态

| 数据 | 存哪 | 说明 |
|---|---|---|
| 视频文件 | `Documents/` | 相对路径即稳定 ID（`VideoItem.id`） |
| 播放进度 | UserDefaults `progress.snapshot.v1` | `positions` / `totals` / `lastPlayed` / `order`（最多 60 条）/ `watched` |
| 文件夹显示名 | UserDefaults `folder.displayNames.v1` | 只影响界面，磁盘目录名与视频 ID 都不变 |
| 设置 | UserDefaults | 键名集中在 `AppSettings.Key` |
| 缩略图 | 内存 NSCache | 取第 5 秒帧，失败回退第 0 帧，再失败回退占位图标 |

视频重命名与「移到文件夹」会迁移进度与已看标记（ID 随路径变化）；删除视频或文件夹会一并清掉记录。

---

## 七、已知边界（有意为之）

1. **MKV / AVI 等容器播不了**。AVPlayer 是系统解码器，这是刻意的取舍——画中画、AirPlay、HDR 在 AVPlayer 上零成本，换 mpv 就要重建整条 `AVSampleBufferDisplayLayer` 管线。真要换，只需替换 `PlayerModel` 与 `VideoSurface` 两处，UI 层一行不用动。不支持的扩展名仍会出现在列表里（带警告图标），点开会提示转成 mp4 / mov。
2. **`ts` / `m2ts` 不当作可播**。AVPlayer 只在 HLS 分片里认 MPEG-TS，独立 `.ts` 文件经常失败。
3. **不做字幕**（外挂 / 内嵌都不做）、**不做画中画**、**不做音轨选择**。
4. **不做局域网传输**。要传文件用访达的文件共享或「文件」App 拖拽，Documents 在系统里就是可见目录，不需要 App 自带 HTTP 服务器。
5. 相册导入拿到的是**导出版本**（相册里做过的剪辑会生效），iCloud「优化存储」的原片需要先下载。

---

## 八、继续开发前值得知道的几件事

- **玻璃配方**在 `Support/Glass.swift`：`.ultraThinMaterial` → 渐变染色 → 0.75pt 上亮下暗描边 → 外投影；三种预设 `.control` / `.panel` / `.subtle`。用法 `.glass(Circle())` 或 `.glass(cornerRadius: 20)`。
- 刻意**没用** iOS 26 的 `glassEffect`：需要 Xcode 26 工具链，CI 跑在 `macos-15` 上不稳；原型本来就是自定义暗色玻璃，用 Material 能 1:1 还原。
- **配色**在 `Palette.swift`，数值与 `preview/ui-v3.html` 的 `:root` 对应，改一处等于改两边。
- 播放页的倍速与模式存在 `PlayerScreen` 这一层，切集不丢、退出即丢——这是设计，不是 bug。
