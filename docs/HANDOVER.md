# 交接文档 · 幕间（工程名 LocalPlayer）

> 最后更新：2026-11-12 16:30
> 仓库：<https://github.com/loinz-Max/localplayer>（public，可自由 clone）
> 当前版本：**0.0.1 (001)**｜部署目标 iOS 17.0｜bundle id `com.loinzmax.localplayer`
> 规模：25 个 Swift 文件、约 5400 行，零第三方依赖
> 整理前快照：tag `snapshot-2026-11-12`

一句话：这是一个只给自己用的 iOS 本地视频播放器，SwiftUI + AVPlayer，视频只躺在 App 的 `Documents` 里，不联网、不登录、不上传。

---

## 0. 六十秒看懂

| 你关心的事 | 答案 |
|---|---|
| 现在能日常用吗 | 能。0.0.1 已装机，真机跑过三轮 |
| 还差什么才「完整」 | 锁屏/控制中心媒体控制、画中画（第 6 节 P1） |
| 需要 Mac 吗 | 不需要。编译和出包全在 GitHub Actions |
| 需要开发者账号吗 | 不需要。免费 Apple ID + 爱思助手自签，7 天有效 |
| 改完怎么看到效果 | push 到 `main`，Actions 自动编译 + 出图 + 出 ipa |
| 设计稿在哪 | `preview/` 两个 HTML。**但它们已经落后于代码，以代码为准**（第 5 节） |
| 最大的坑是什么 | 玻璃在纯黑底上没东西可透，调透明度救不回来（第 5 节） |

---

## 1. 接手：四步

```bash
git clone https://github.com/loinz-Max/localplayer.git
cd localplayer
git config user.name  "hayatlia58-blip"
git config user.email "你的 GitHub 邮箱"
```

1. **读两份文档**：本文件（进度 + 坑）+ `docs/DESIGN.md`（视觉规格）。
2. **看当前界面**：`ci-shots` 分支有 15 张模拟器实拍图 →
   <https://github.com/loinz-Max/localplayer/tree/ci-shots>
3. **要改代码**：确认推送权限（第 2.3 节），改完 `git push origin main`。
4. **在 WorkBuddy 里接着干**，直接说：

   > 读 LocalPlayer 仓库的 `docs/HANDOVER.md` 和 `docs/DESIGN.md`，接着做第 6 节的待办。

> **协作者权限已就绪**：`hayatlia58-blip` 于 2026-11-12 接受邀请，对仓库有 write 权限，可直接 push `main`。
>
> 换电脑/换账号时注意：WorkBuddy 的会话记忆跟着账号走，读不到上一轮聊天记录。**凡是要留下的信息都在本文件里**，别指望记忆。

---

## 2. 环境与工具链

### 2.1 没有 Mac 怎么编译

push 到 `main` 会自动跑 `.github/workflows/ios-ipa.yml`，两个 job 并行：

| Job | 产出 | 在哪拿 |
|---|---|---|
| `打包未签名 ipa` | `LocalPlayer-unsigned-ipa` | run 页面底部 Artifacts |
| `模拟器截图` | 15 张 PNG | 推到 `ci-shots` 分支（不登录也能看） |

- 编译失败时，workflow 会把错误写进 GitHub 的 annotation，不用翻日志。
- 新仓库第一次跑，必须去 Settings → Actions → General → Workflow permissions 选 **Read and write**，否则推 `ci-shots` 失败（编译不受影响，只是没截图）。
- 有 Mac 时：`brew install xcodegen && xcodegen generate && open LocalPlayer.xcodeproj`，或 `scripts/dev.sh "iPhone 16"`。

### 2.2 装机（爱思助手签名）

1. 下载 ipa → 爱思「工具箱 → IPA 签名」，填 Apple ID（开了双重认证的用 App 专用密码）。
2. 安装后到「设置 → 通用 → VPN 与设备管理」信任证书，iOS 16+ 还要开「开发者模式」。
3. **免费证书 7 天过期**，重签时只要 bundle id 不变，就能覆盖安装、保住视频和进度。
4. bundle id 撞车会导致签名失败。当前用的是 `com.loinzmax.localplayer`，别再改。

### 2.3 权限（换 GitHub 账号还能不能改）

仓库 public，任何人能看能 clone，push 只对 owner / collaborator 开放。三条路：

| 方式 | 操作 | 代价 |
|---|---|---|
| 协作者 | 用 `hayatlia58-blip`（已有 write）直接 push | 无 |
| Fork + PR | 别的账号 fork 后提 PR，合并仍需 owner | 每次走 PR |
| 直接登 owner | 用 `loinz-Max` 登录 | 最省事，但账号混用 |

Windows 上凭据存在「凭据管理器 → `git:https://github.com`」，**换账号要先删这条**，否则一直拿旧账号推（403）。

### 2.4 网络（本机代理会挡 git）

| 现象 | 处理 |
|---|---|
| `git push` 报 `CONNECT tunnel failed 502` / `schannel: server closed` | 用 `node scripts/push-api.js` 走 Git Data API 推送 |
| `raw.githubusercontent.com` 502 | 改用 `api.github.com/repos/.../contents/<path>?ref=<branch>` 取 base64 |
| `api.github.com` 返回 403 rate limit | 未认证只有 60 次/小时。用 `git fetch origin ci-shots` 判断 CI 是否跑完（commit message 是 `shots: <sha>`），用 `git show origin/ci-shots:xx.png > out.png` 取图 |

---

## 3. 仓库结构

```
localplayer/
├─ README.md                     项目说明：功能、怎么跑、边界
├─ CHANGELOG.md                  更新记录（未发布 + 0.0.1）
├─ project.yml                   XcodeGen 工程描述（唯一的工程配置来源）
├─ Info.plist                    相册读用途、文件共享、后台音频
├─ .github/workflows/ios-ipa.yml 云端编译 + 截图 + 出包 + 失败取错误
├─ docs/
│  ├─ HANDOVER.md                本文件
│  ├─ DESIGN.md                  视觉与交互规格
│  └─ ACCEPTANCE-2026-11-12.md   0.0.1 那轮实机验收的问题与结论（存档）
├─ preview/
│  ├─ ui-v3.html                 资料库 + 设置的整体方案
│  ├─ ui-v5-player.html          播放页改版
│  └─ ui-preview.html            最早的初版预览，仅存档
├─ scripts/
│  ├─ dev.sh                     有 Mac 时一键编译装机
│  └─ push-api.js                git 通道被挡时的推送兜底
└─ LocalPlayer/
   ├─ App/          入口、EnvironmentObject 注入、AVAudioSession
   ├─ Models/       VideoItem / SortKey / PlayMode
   ├─ Player/       PlayerModel（AVPlayer 封装）、VideoSurface
   ├─ Services/     LibraryStore / ProgressStore / AppSettings / ImportService / ThumbnailLoader
   ├─ Support/      Glass / Palette / HUD / Fmt / 亮度 / 音量 / 方向锁 / 抓帧预览 / DebugSeed
   └─ Views/        Library / Cards / Menus / Player / Panels / Settings / PhotoPicker
```

**改代码前先想清楚落点**：样式进 `Support/`，状态进 `Services/`，纯 UI 进 `Views/`。`GlassStyle` 和 `Palette` 改一处等于全站换肤，别在 View 里硬编码颜色。

---

## 4. 数据与状态

| 数据 | 存哪 | 规则 |
|---|---|---|
| 视频文件 | `Documents/` | **相对路径就是 ID**（`VideoItem.id`），改路径等于换 id |
| 播放进度 | UserDefaults `progress.snapshot.v1` | positions / totals / lastPlayed / order（上限 60 条）/ watched |
| 文件夹显示名 | UserDefaults `folder.displayNames.v1` | 只影响界面，磁盘目录名不动 |
| 设置 | UserDefaults | 键名集中在 `AppSettings.Key`，别再手写字符串 |
| 缩略图 | 内存 NSCache | 取「时长 12%，不早于 3 秒」那一帧，失败退 3 秒 → 首帧 → 占位图 |

几条必须遵守的迁移规则：

- **视频重命名**要调 `progress.renamePath(from:to:)`，否则进度和已看标记会丢。
- **移动视频**同理，id 变了必须迁移。
- **文件夹重命名只改显示名**。真改目录名会让里面所有视频 id 失效。
- 「播完」的语义是 `watched`（打勾），不是清空记录；播完要继续留在「最近播放」里。

---

## 5. 设计硬规则

这些是已经付过学费的决定，改之前先读原因。

1. **原型不是真相，代码是。** `preview/ui-v3.html` 还是浅色玻璃 + 带框空状态的旧版，实际实现早就是深色四层玻璃 + 无框空状态。要改界面，先改代码里的 `GlassStyle` / `Palette`，有空再回写原型。
2. **玻璃是四层，不是六层**：`Material.ultraThinMaterial` → 渐变染色 → 0.75pt 上亮下暗描边 → 外投影。文档里如果还写六层，那是旧版本的笔误。
3. **纯黑底上玻璃永远是黑的。** 没有内容可透，染色调多透都看不出层次。资料库背景顶部那层 2.8% 白雾（`LibraryView.backgroundLayer`）就是干这个的，别当废代码删掉。
4. **降低染色 alpha 必须同步加亮描边**（约 +0.04），否则控件边界会散在画面里。
5. **白玻璃方案试过，失败。** 纯黑背景 + 白染色，亮度等于 255×alpha：a=0.34 是灰块，a=0.9 又不透了。别再试。
6. **播放页控件必须暗色染色。** 白色染色在亮画面上等于加亮，白图标会糊。
7. **轻提示只有一套**：`Support/HUD.swift` 的 `HUDLabel`，toast / 长按倍速 / 拖动时间标签都用它。别在页面里另写胶囊。
8. **倍速与播放模式只在本次播放有效**，存在 `PlayerScreen` 层，切集不丢、退出即丢。设置里的是起点值。
9. **防误触是手动锁**：播放页左下角圆键，锁上后点屏幕只亮出解锁键，没有任何长按手势。
10. **想要方向锁生效，就不要用 modal 呈现页面。** `fullScreenCover` 有独立的方向策略，会绕开 `AppDelegate` 的 mask。
11. **不支持格式仍显示在列表里**，带警告图标，点开才提示转码。
12. **零第三方依赖，不联网。** 加任何依赖前先想清楚要不要为它维护 CI。

---

## 6. 待办与已知问题

### 6.1 待办（按优先级）

**P0 · 真机第三轮验收**（代码已推，截图验不出来）

- [ ] 「播完暂停」停在最后一帧后，中间键是否变成重播图标，点一下是否从头播
- [ ] 播完的卡片右下角是否变成勾，且该条目仍在「最近播放」里
- [ ] 退出播放页后，系统亮度是否恢复成进入前的值
- [ ] 导入大文件时底部是否出现「正在导入 3/8」，界面是否还能滑动、能点开视频
- [ ] 玻璃在真实照片、真实视频上的观感（模拟器只有测试色块）
- [ ] 长按倍速提示的位置与大小是否合适

**P1 · 系统集成**（能力已经具备，只差接线）

- 锁屏 / 控制中心媒体控制：`Info.plist` 已开 `UIBackgroundModes: audio`，`AVAudioSession` 是 `.playback`，切后台声音会继续，但**没接 `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter`**，所以锁屏是空的、不能暂停和切集。约 100 行。
- 画中画：加 `AVPictureInPictureController`，约 100 行 + delegate。这个 App 最实用的场景就是「看视频回微信」。

**P2 · 小功能补齐**

- 「⋯」菜单的排序只露了名称/日期，`SortKey` 里的「最近播放」「文件大小」没有入口（排序逻辑本身已实现）。
- 存储页加「清空播放记录」「清理失效记录」（`ProgressStore.forget` 目前没人调用）。
- 多选只有删除、移动，缺「批量标记已看」。

**P3 · 工程债**

- `LibraryView.swift` 1073 行、`PlayerScreen.swift` 1052 行，可按「手势 / 浮层 / 控制层」拆成 extension 文件。
- 零单元测试。`Formatters`、`ProgressStore` 的「末尾 15 秒算看完」、四种排序都适合补 XCTest，CI 目前只编译不跑测试。

**P4 · 可选**

- iOS 16 兼容：当前 17.0，要降需给 `MagnifyGesture`、`requestGeometryUpdate` 加可用性判断。
- 原生 `.glassEffect()`：iOS 26 API，需要在 workflow 里 `xcode-select` 到 Xcode 26，部署目标可以仍留 17。

### 6.2 已决策不做（别再提）

| 项 | 原因 |
|---|---|
| 搜索框 | 视频不多，加了是噪音；相关死代码已删 |
| 字幕 / 音轨切换 | AVPlayer 对 mkv 内封字幕基本无解，做出来是「有的能用有的不能」 |
| 海报墙 / 收藏 / 标签 / 评分 | 文件夹层级够用 |
| 局域网传输 | 用「文件」App 或访达共享，Documents 本身就是可见目录 |
| 抓帧存相册 | 曾做过，按需求删了，`FrameGrabber` 和相册写权限都已移除 |
| 白色液态玻璃 | 见第 5 节第 5 条，算术上不成立 |

### 6.3 还没定的小事

- **版本号策略**：现在一直是 0.0.1，CHANGELOG 有「未发布」段。是维持覆盖装，还是每批升 0.0.2 / 0.0.3？定了要同步改 `project.yml` 的 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`。
- **列表循环下播完是否自动标已看**：现在的实现是「播完就打勾」（单集循环除外）。如果你习惯挂着循环当背景放，可能会积累一堆勾，需要改成只在「播完暂停」时标记。
- **菜单尺寸**：宽 200 / 行高 44，一直没确认是否偏小。

---

## 7. 踩坑清单（按现象查）

**构建与 CI**

| 现象 | 原因 / 处理 |
|---|---|
| 编译报错但看不到细节 | 错误会写进 check-run 的 annotations，也可以从 workflow 的「提取编译错误」步骤读 |
| CI 报 runner 分配失败 | macOS runner 容量问题，重新触发即可 |
| 推 `ci-shots` 失败 | 仓库 Workflow permissions 不是 Read and write |
| 截图里播放键后面有个大白圆 | 不是 UI，是 `DebugSeed` 示例视频里的缓慢移动圆 |

**截图**

| 现象 | 原因 / 处理 |
|---|---|
| 横屏截图内容转了 90° | `simctl io screenshot` 只拍竖屏 buffer。App 内部确实转了横屏，布局是对的，别去改布局 |
| 某个面板截不到 | 用 `-panel speed\|queue\|lock\|level\|boost` 强制打开，配合 `-keepChrome 1` |
| 截图场景里状态莫名消失 | 示例视频只有 8 秒，任何「真加速」都会在截图前播完并自动切集，父视图一重建状态就归零。**截图场景只点亮 UI 状态，别改播放速度** |

**界面**

| 现象 | 原因 / 处理 |
|---|---|
| 缩略图超出卡片 | `ThumbnailView` 只给了 width 没给 height，加 `size` 参数宽高锁死，`clipped()` 要放在 `clipShape()` 之前 |
| 换了 `UIVisualEffectView` 参数外观却不变 | 用 `UIViewRepresentable` 包它是真实子视图，会盖住同层的 SwiftUI 染色。这条路走不通，别浪费时间 |
| 玻璃调透明没效果 | 纯黑底没有内容可透，见第 5 节第 3 条 |
| 长按 2× 松手不复原 | `onLongPressGesture(perform:)` 与松手顺序不定，改成 `onPressingChanged` 自己计时 + 令牌 |
| 边加速边跳进度 | 长按加速中手指移动要立刻 `endBoost()` 再进 seek，两个手势不能同时生效 |
| 方向锁只管播放页 | 播放页曾用 `fullScreenCover`，模态有独立方向策略。改成同层 `.overlay` |
| 播放列表里当前视频被甩到末尾 | `PlayerScreen(queue:)` 每次重算，进播放页时要冻结队列到 `playingQueue` |

**文件与数据**

| 现象 | 原因 / 处理 |
|---|---|
| 设置里数得到视频、列表里不显示 | 外部写入的路径带 `/private` 前缀，`folder` 算错。`VideoItem.relativePath` 做了前缀兼容 |
| 从爱思/文件 App 拷完没反应 | `LibraryStore` 监听 Documents 目录 + `scenePhase` 回前台重扫 + 下拉刷新 |
| 改名后进度丢了 | 忘了调 `progress.renamePath(from:to:)` |
| `.gitignore` 的目录规则误伤 | 不带斜杠的 `shots/` 会匹配任意层级，要用 `/shots/` 只锁根目录。排查用 `git check-ignore -v <path>` |

---

## 8. 发布与验收流程

**改完一次的标准动作**

1. 改代码 → `git commit -m "中文一句话说清做了什么"` → `git push origin main`
2. 等 Actions 两个 job 变绿（约 8–12 分钟）
3. 到 `ci-shots` 分支核对截图，重点看改动涉及的那几屏
4. 下载 ipa → 爱思签名 → 覆盖安装
5. 按第 6.1 节 P0 清单在真机上过一遍
6. 有问题记进 `docs/ACCEPTANCE-<日期>.md`，改完再打一轮

**版本记录约定**

- `CHANGELOG.md` 分两段：「未发布」积累改动，「0.0.1」这种已发布版本固化。
- 每次发版同步 `project.yml` 里 `MARKETING_VERSION`（展示版本）和 `CURRENT_PROJECT_VERSION`（构建号，三位数递增）。
- 重要的结构调整打 tag，并同时生成两份备份：

```bash
git bundle create ../LocalPlayer-backup-<日期>.bundle --all   # 完整历史，可 clone 恢复
git archive --format=zip -o ../LocalPlayer-src-<日期>.zip HEAD # 干净源码快照
git tag -a snapshot-<日期> -m "说明" && git push origin snapshot-<日期>
```

---

## 9. 给它加功能前，先问三个问题

1. **这是一个人用的东西吗？** 视频不多、不需要多账号、不需要云同步。功能加了就是维护成本。
2. **能不能用系统自带能力？** AVPlayer 已经免费给了 AirPlay、HDR、硬件解码，换播放内核等于把这些全丢了。
3. **截图能不能验证？** 验证不了的改动（导入进度、锁屏、旋转）一定要真机过一遍再算完成。
