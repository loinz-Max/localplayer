# 交接文档 · 本地播放器（LocalPlayer）

> 最后更新：2026-11-11 23:05
> 仓库：<https://github.com/loinz-Max/localplayer>（**public**）
> 当前状态：**0.0.1 已装，第一批「播放收尾」已修** —— 播完可重播、播完自动标记已看、退出恢复系统亮度；CI 绿，等真机验收。
> 最新提交：`8cf6ffa`（播放收尾 + 亮度恢复）｜最新成功构建：run `43173840205`

---

## 0. 换电脑 / 换账号，从这四步开始

```bash
git clone https://github.com/loinz-Max/localplayer.git
cd localplayer
git config user.name  "hayatlia58-blip"
git config user.email "你的 GitHub 邮箱"
```

> **协作者权限已就绪**：`hayatlia58-blip` 已于 2026-11-12 接受邀请，对 `loinz-Max/localplayer` 有 write 权限，可以直接 push `main`。不用再走任何邀请流程。

1. **先读两个文件**：本文件（进度 + 坑）和 `DESIGN.md`（界面规格；唯一设计真相是 `preview/ui-v*.html`）。
2. **看效果不用 Mac**：`ci-shots` 分支里是最新模拟器截图 → <https://github.com/loinz-Max/localplayer/tree/ci-shots>；ipa 在 Actions 页的 Artifacts 里。
3. **要改代码**：先确认推送权限，见第 1 节。
4. **在 WorkBuddy 里开工**直接说：

   > 读 LocalPlayer 仓库的 HANDOVER.md 和 DESIGN.md，接着做第 7 节的待办。

> 不需要的东西：本机不需要 Xcode（CI 用 macos-15 编译）、不需要 Apple 开发者账号（免费号自签即可）、App 本身完全离线。
>
> ⚠️ WorkBuddy 的会话记忆跟着账号走，换了 WorkBuddy 账号或电脑就读不到上一轮的聊天记录。
> 所以**凡是后续要用的信息都写进了本文件**，别指望会话记忆。

---

## 1. 仓库与权限（换个 GitHub 账号还能不能改？）

**仓库是 public**：任何人（哪怕没登录）都能看代码、看提交历史、看 `ci-shots` 截图、clone、fork。
但 **push 只对 owner 和 collaborator 开放**。

明天用另一个 GitHub 账号，三条路：

| 方式 | 你要做什么 | 代价 |
|---|---|---|
| **A. 协作者权限**（✅ 已生效） | `hayatlia58-blip` 已被加为 collaborator（write），2026-11-12 接受。用这个账号 clone 后直接 push 即可 | 无 |
| **B. Fork + Pull Request** | 用别的账号 Fork → 在自己 fork 上改 → 提 PR；合并仍需 `loinz-Max` | 不用邀请，但每次要走 PR |
| **C. 直接登 loinz-Max** | 那台电脑用 `loinz-Max` 登录（密码或 PAT） | 一个账号走到底，最不容易乱 |

**其它注意**

- 想改私有：Settings → General → 最下方 Change visibility。私有后 Actions 免费额度 2000 分钟/月，`ci-shots` 截图链接也不再公开。
- Windows 上凭据存在「凭据管理器 → `git:https://github.com`」，**换账号要先删掉这条**，否则一直用旧账号推（会 403）。
- 新账号 push 报 `403`，基本就是「登录的账号对这个仓库没有写权限」。

---

## 2. 当前进度

| 阶段 | 状态 | 证据 |
|---|---|---|
| 界面原型 v3（资料库 / 抽屉 / 设置，10 屏） | ✅ 定稿 | `preview/ui-v3.html` |
| 播放页改版原型 v5（竖 / 横 / 倍速面板 / 设置页） | ✅ 定稿 | `preview/ui-v5-player.html` |
| SwiftUI 实现 | ✅ 编译通过 | run `43043048757` |
| 模拟器截图视觉校对 | ✅ 已做 3 轮 | `ci-shots` 分支 10 张图 |
| 真机安装试用 | ⏳ **只差这一步** | 见第 6 节清单 |
| 文档同步（README / DESIGN / HANDOVER） | ✅ 持续更新 | — |

**做过的事（按时间）**

1. 按原 v3 原型重写全部界面（玻璃配方、双列网格、长按菜单、右侧抽屉）。
2. 收尾：README / DESIGN 重写、删伪造的「继续观看」数据、`ts/m2ts` 移出可播白名单、设置键名收进 `AppSettings.Key`。
3. P2 功能：排序加「文件大小」、防误触 / 自动隐藏时长、文件夹重命名（只改显示名）/ 删除、视频「移到文件夹」。
4. **播放页按参考图改版**：顶栏只留关闭与列表、中部三圆等大（竖 58 / 横 62）、底部通栏进度条、右下倍速键 + 110 宽窄浮层（五档）。播放设置抽屉整体删除，三项设置移进 App 设置页「播放界面」，并新增「默认画面」。
5. **修 bug**：外部写入（爱思助手 / 文件 App / AFC）的文件路径带 `/private` 前缀，导致 `folder` 算错 → 设置里数得到、列表里看不到。同时补了目录监听、回前台重扫、下拉刷新。

---

## 3. 代码地图

```
LocalPlayer/
├─ App/LocalPlayerApp.swift          入口、EnvironmentObject 注入
├─ Models/VideoItem.swift            条目模型；relativePath 兼容 /private 前缀（重要）
├─ Player/
│  ├─ PlayerModel.swift              AVPlayer 封装：时间轴 / 倍速 / 缓冲 / 失败态
│  └─ VideoSurface.swift             UIViewRepresentable 包 AVPlayerLayer
├─ Services/
│  ├─ LibraryStore.swift             扫描 Documents、导入/删除/重命名/移动、目录监听
│  ├─ ProgressStore.swift            进度 / 已看 / 最近播放（UserDefaults 单键快照）
│  ├─ AppSettings.swift              所有设置项 + 键名枚举 + 播放页用的静态读取
│  ├─ ThumbnailLoader.swift          缩略图（取第 5 秒帧）+ 时长缓存
│  └─ PhotoImporter.swift            相册导入（转存沙盒，命名 日期_序号）
├─ Views/
│  ├─ LibraryView.swift              资料库：网格 / 菜单 / 弹窗 / 导入 / 下拉刷新
│  ├─ Cards.swift                    视频卡片、文件夹卡片、缩略图
│  ├─ LibraryMenus.swift             长按菜单、导入菜单、更多菜单、移到文件夹
│  ├─ PlayerScreen.swift             播放页：顶栏 / 三圆 / 进度条 / 倍速浮层 / 手势 / 锁定
│  ├─ PlayerPanels.swift             播放列表抽屉 + 倍速面板
│  └─ SettingsView.swift             设置页（播放 / 播放界面 / 存储 / 关于）
├─ Support/                          Glass（玻璃配方）、Palette（色板）、Fmt、DebugSeed 等
preview/ui-v3.html                   资料库与整体结构原型
preview/ui-v5-player.html            播放页改版原型（含设置页）
scripts/dev.sh                       本机 Mac 一键跑模拟器
scripts/push-api.js                  git 通道被代理挡住时的推送兜底（见第 5 节）
project.yml                          XcodeGen 工程描述（部署目标 iOS 17）
```

---

## 4. 怎么编译 / 怎么出包

**有 Mac**

```bash
brew install xcodegen
xcodegen generate
open LocalPlayer.xcodeproj      # ⌘R
# 或者： scripts/dev.sh "iPhone 16"
```

**没 Mac（现在走的就是这条路）**

push 到 `main` 会自动触发 `.github/workflows/ios-ipa.yml`，两个 job：

- `模拟器截图`：跑 10 屏截图 → 推到 `ci-shots` 分支（不登录也能看）
- `打包未签名 ipa`：产物名 `LocalPlayer-unsigned-ipa`，在 run 页面最下方 Artifacts 下载

**装机**：ipa 未签名，用爱思助手「工具箱 → IPA 签名」签一次（填 Apple ID；开了双重认证的号用 App 专用密码），再安装。装完在 设置 → 通用 → VPN 与设备管理 里信任证书；iOS 16+ 再开「开发者模式」。

**新仓库第一次跑 Actions 必须做**：Settings → Actions → General → Workflow permissions 选 **Read and write**，否则推 `ci-shots` 会失败（编译不受影响，只是看不到截图）。

---

## 5. 踩过的坑（省点排查时间）

| 现象 | 原因 / 处理 |
|---|---|
| `git push` 报 `CONNECT tunnel failed, response 502` / `schannel: server closed` | 本机代理挡了 `github.com` 的 git 传输。`api.github.com` 正常，可 `node scripts/push-api.js` 走 Git Data API 推（用法见文件头注释） |
| `raw.githubusercontent.com` 502 | 同样被代理挡。改用 `api.github.com/repos/.../contents/<path>?ref=<branch>` 取 base64 解码 |
| 设置里数得到视频、列表里不显示 | 已修：外部写入路径带 `/private` 前缀，`folder` 算错。关键是 `VideoItem.relativePath(of:in:)` 按前缀匹配 |
| 从爱思 / 文件 App 拷完文件，App 里没反应 | 已修：`LibraryStore` 监听 Documents 目录 + `scenePhase` 回前台重扫 + 下拉刷新 |
| 截图里播放键后面有个大白圆 | 不是 UI，是 `DebugSeed` 生成的示例视频里那枚「缓慢右移的圆」 |
| CI 报 runner 分配失败 | macOS runner 容量问题，重新触发即可，不是代码问题 |
| 横屏截图内容旋转 90° | `simctl io screenshot` 只拍竖屏 buffer 的已知现象，不代表真机有问题 |

---

## 6. 明天第一件事：真机验收清单

装上最新 ipa 后按顺序过一遍，有问题记下来（附截图）：

- [ ] 启动后能列出视频；**下拉能刷新**；从爱思推文件后切回 App 会自动出现
- [ ] 播放页：三圆等大且居中；进度条通栏、两端时间对齐
- [ ] 右下倍速键点开 → 面板贴在键上方、不压中部控件；选档后数字跟着变
- [ ] 列表抽屉：展开时控件收起；点其他集能切
- [ ] **横屏**：三圆位置、进度条、倍速面板是否都正常（模拟器验不出来）
- [ ] 手势：横滑调进度、左半屏亮度、右半屏音量、双击左右 ±10 秒、**长按 2× 快进**（松手恢复）
- [ ] 播放页左下角锁定键：锁上后点屏幕只亮出解锁按钮，点它能解锁；长按画面不再有任何效果
- [ ] 导入到子文件夹后，面包屑与「回到资料库」是否正常

---

## 7. 待办（按优先级）

1. **真机第二轮验收**：重点看液态玻璃的实际观感、亮度/音量顶部横条、左下角锁定键、方向锁定是否真的按设置转。
2. ~~bundle id 改唯一~~：已改成 `com.loinzmax.localplayer`（`project.yml` 两处 + workflow 的 `BUNDLE` 都同步了）。注意这是**换了一个新 App**：旧包 `com.example.localplayer` 里的视频与进度不会迁移，需重新导入。
3. ~~锁定方向~~：已做——设置 →「播放界面」→ 旋转锁定（跟随系统 / 竖屏锁定 / 横屏锁定），`OrientationController` + `AppDelegate` 生效。
4. **iOS 16 兼容**（可选）：当前部署目标 17.0；要在旧机装需降到 16，并给 `MagnifyGesture`、`requestGeometryUpdate` 加可用性判断。
5. ~~抓帧存相册~~：按需求删掉了（`FrameGrabber.swift` 与 `NSPhotoLibraryAddUsageDescription` 都已移除），不要再加回来。
6. 其它细节：菜单 200 宽 / 44 行高是否偏小（一直没定）。
7. **原型待同步**：`preview/ui-v3.html`（资料库）与 `ui-v5-player.html` 还是浅色玻璃 + 带框空状态，实际代码已是液态玻璃 + 无框空状态。

---

## 8. 设计约定的几条硬规则

- **原型即真相**：`preview/ui-v3.html`（资料库）+ `preview/ui-v5-player.html`（播放页）。改界面前先改原型，再改 SwiftUI。
- **倍速 / 播放模式只在本次播放有效**：存在 `PlayerScreen` 层，切集不丢、退出即丢。设置页里的「默认值」只是起点。
- **文件夹重命名只改显示名**：磁盘目录名不动，否则里面视频的 id（相对路径）、进度、已看记录全要重写。
- **视频重命名改磁盘文件名**：文件名 = id，改名后自动迁移进度与已看标记。
- **不支持格式仍显示在列表**，带警告图标，点开才提示转码。
- **零第三方依赖**，不联网、不上传。
- **液态玻璃自己画**：`Glass.swift` 六层（材质/染色/镜面高光/底部厚度/边缘光/内圈高光/投影），不用原生 `glassEffect`（Xcode 26 才有）。
- **防误触是手动锁**：播放页左下角锁定键（与右下角倍速键对称）；锁上后点屏幕只会亮出同一位置的解锁按钮，点它解锁，没有任何长按手势。
