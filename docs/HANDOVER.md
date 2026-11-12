# 交接文档 · 幕间（工程名 LocalPlayer）

> 最后更新：2026-11-12 22:30
> 仓库：<https://github.com/loinz-Max/localplayer>（public，可自由 clone）
> 当前版本：**0.0.2**（构建号 002；关于页只显示版本号，不再带构建号）｜部署目标 iOS 17.0｜bundle id `com.loinzmax.localplayer`
> 最新提交：`83f8456`（长按浮起最终版）｜最新成功构建：run `43234223189`
> 规模：26 个 Swift 文件、约 5996 行，零第三方依赖
> 快照 tag：`snapshot-2026-11-12`（0.0.1 那轮）、`snapshot-2026-11-12-night`（0.0.2 交接点）

一句话：这是一个只给自己用的 iOS 本地视频播放器，SwiftUI + AVPlayer，视频只躺在 App 的 `Documents` 里，不联网、不登录、不上传。

---

## 0. 项目进度

### 0.1 六十秒看懂

| 你关心的事 | 答案 |
|---|---|
| 现在能日常用吗 | 0.0.1 装过并跑过三轮真机。仓库里的 **0.0.2 一次都还没上过真机**，它叠了第 5–11 轮共 7 批改动（品牌、方向锁、锁屏遥控、顶栏搜索、长按浮起、设置精简），装机后要按 6.1 逐条过 |
| 它叫什么 | 桌面名 **幕间**（Interlude），工程名/仓库名/bundle id 仍是 `LocalPlayer` |
| 还差什么才「完整」 | 只剩画中画（第 6.1 节 P1）——锁屏 / 控制中心 / 耳机遥控已接好 |
| 需要 Mac 吗 | 不需要。编译和出包全在 GitHub Actions |
| 需要开发者账号吗 | 不需要。免费 Apple ID + 爱思助手自签，7 天有效 |
| 改完怎么看到效果 | push 到 `main`，Actions 自动编译 + 出 20 张截图 + 出 ipa，全程约 10 分钟 |
| 设计稿在哪 | `preview/` 两个 HTML。**但它们已经落后于代码，以代码为准**（第 5 节） |
| 最大的坑是什么 | 玻璃在纯黑底上没东西可透，调透明度救不回来（第 5 节第 3 条） |

### 0.2 迭代记录

从「能装能放」到现在的全部轮次，每轮都对应一次绿了的 CI。

| # | 交付内容 | 提交 | 状态 |
|---|---|---|---|
| 1 | **0.0.1 基线**：资料库网格/列表、多选、长按菜单、播放页双抽屉、拖动小窗预览、进度角标、设置四级菜单、默认名称升序、版本号落地 | `c38c45e` | ✅ 已装真机 |
| 2 | **播放收尾**：播完可重播（中间键变 ↺）、播完自动标已看、退出恢复系统亮度 | `8cf6ffa` | ✅ 已验 |
| 3 | **观感与导入**：玻璃整体调透一档 + 描边提亮、背景顶部 2.8% 白雾、提示统一 HUD、导入后台化 + 进度胶囊、删搜索死代码 | `47501e6` → `140addb` | ✅ 已验 |
| 4 | **仓库整理**：`.gitignore` 误伤修正、README/DESIGN 对齐代码、验收清单归档 `docs/`、删三处死代码 | `3ae236a` → `a34bc1c` | ✅ 文档类 |
| 5 | **品牌**：桌面名改「幕间」+ 关于页 `INTERLUDE` 副标；图标换成深底液态玻璃棱镜 | `d1fa741`、`d24e81c` | ⏳ 待看桌面效果 |
| 6 | **方向**：方向设置只作用于播放页，资料库与设置固定竖屏，退出自动转回 | `3e3c7b4` | ⏳ 待真机验 |
| 7 | **系统集成**：锁屏 / 控制中心 / AirPods / 车机的正在播放与遥控（新 `Services/NowPlayingService.swift`） | `227ff27` | ⏳ 待真机验 |
| 8 | **顶栏**：左侧加搜索（跨库按文件名、结果标所在文件夹）、标题独立一层居中不随按钮偏移、根目录标题改 `Interlude`、面包屑改 `‹ Interlude` | `abe9091`、`c1b08c8` | ⏳ 待真机验 |
| 9 | **细节**：长按倍速改数值胶囊（去系统菜单箭头）、移除「资料库排版」、版本号只显示 `0.0.2`、卡片副标题不再重复已看百分比 | `d8ddc63`、`277663c` | ⏳ 待真机验 |
| 10 | **长按浮起**：原位留空 + 放大 1.09 + 1pt 亮边 + 散投影 + 弹簧；菜单锚点按放大后边缘让位 | `9549d99` → `28cb785` → `43715c9` | ⏳ 待真机验 |
| 11 | **设置精简**：一级菜单去掉每行右侧状态摘要，只留图标 + 名称 + 箭头 | `0900731` | ⏳ 待真机验 |

三轮真机验收提出并已关闭的问题，逐条记在 [`ACCEPTANCE-2026-11-12.md`](ACCEPTANCE-2026-11-12.md)。

### 0.3 距离「完整」还差什么

按「补上之后体感提升最大」排序：

1. **真机把第 5–11 轮过一遍**（P0）——0.0.2 攒了 7 轮改动没上过真机：品牌、方向锁、锁屏遥控、顶栏搜索、长按浮起、设置精简。
2. **画中画**（P1）——本地播放器最高频的真实场景就是「边看边回消息」。
3. **排序入口补齐 + 清空播放记录**（P2）——`SortKey` 实现了四种排序，界面只露了两种。
4. 工程债（P3）：拆 1000 行视图、补单元测试。不影响使用，做之前先想值不值。

---

## 1. 接手：四步

```bash
git clone https://github.com/loinz-Max/localplayer.git
cd localplayer
git config user.name  "hayatlia58-blip"
git config user.email "你的 GitHub 邮箱"
```

1. **读两份文档**：本文件（进度 + 坑）+ `docs/DESIGN.md`（视觉规格）。
2. **看当前界面**：`ci-shots` 分支有 20 张模拟器实拍图 →
   <https://github.com/loinz-Max/localplayer/tree/ci-shots>
3. **要改代码**：确认推送权限（第 2.3 节），改完 `git push origin main`。
4. **在 WorkBuddy 里接着干**，直接说：

   > 读 LocalPlayer 仓库的 `docs/HANDOVER.md` 和 `docs/DESIGN.md`，先告诉我现在的进度和待办，别急着改代码。

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
| `模拟器截图` | 20 张 PNG | 推到 `ci-shots` 分支（不登录也能看） |

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
├─ CHANGELOG.md                  更新记录（0.0.2 未发布 + 0.0.1 已发布）
├─ project.yml                   XcodeGen 工程描述（唯一的工程配置来源）
├─ Info.plist                    桌面显示名「幕间」、文件共享、后台音频、方向声明
├─ .github/workflows/ios-ipa.yml 云端编译 + 截图 + 出包 + 失败取错误
├─ docs/
│  ├─ HANDOVER.md                本文件
│  ├─ DESIGN.md                  视觉与交互规格
│  └─ ACCEPTANCE-2026-11-12.md   0.0.1 那轮实机验收的问题与结论（存档）
├─ preview/
│  ├─ ui-v3.html                 资料库 + 设置的整体方案（**已落后于代码**）
│  ├─ ui-v5-player.html          播放页改版（同样只作参考）
│  ├─ ui-preview.html            最早的初版预览，仅存档
│  └─ shots/                     最初交接包里的 4 张原型效果图（未纳入版本管理）
├─ scripts/
│  ├─ dev.sh                     有 Mac 时一键编译装机
│  └─ push-api.js                git 通道被挡时的推送兜底
└─ LocalPlayer/
   ├─ App/          入口、EnvironmentObject 注入、AVAudioSession
   ├─ Models/       VideoItem / SortKey / PlayMode
   ├─ Player/       PlayerModel（AVPlayer 封装）、VideoSurface
   ├─ Services/     LibraryStore / ProgressStore / AppSettings / ImportService / ThumbnailLoader / NowPlayingService
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
13. **方向：只有播放页能转。** 资料库、设置页由 `AppDelegate` 的 mask 强制竖屏；进播放页时 `OrientationController.setPlayerActive(true)` 才放开设置里的方向，退出自动转回竖屏。别把这段逻辑改成全局——试过一版全局锁，结果在资料库里转手机界面跟着转，很别扭。
14. **长按浮起＝原位留空 + 放大 1.09 + 亮边。** 近黑底上黑影几乎看不见，只做投影和 4% 放大等于没效果（试过两轮才定）。原卡必须 `.opacity(0)` 让位，否则两张叠着会露出错位边缘；菜单锚点要用 `liftedRect()` 按放大后的边缘算，不然会贴在卡片上。
15. **改名只动显示名。** 桌面名走 `Info.plist` 的 `CFBundleDisplayName`（幕间），关于页在 `SettingsView`。`PRODUCT_NAME`、仓库名、bundle id `com.loinzmax.localplayer` **一律不动**——动了就等于换一个新 App，Documents 里的视频和 UserDefaults 里的进度全部拿不回来。

---

## 6. 待办与已知问题

### 6.1 待办（按优先级）

**P0 · 真机验收 0.0.2**（只能真机做，截图验不出来）

你手机上装的是 0.0.1，仓库里的 0.0.2 一次都没上过真机。下面这些全是「代码里有、真机没确认」的：

- [ ] **桌面名与图标**：桌面显示「幕间」；图标是深底玻璃棱镜。若还是旧的蓝三角 → 先重启手机，别卸载（见第 7 节「图标缓存」）
- [ ] **方向**：资料库/设置横过手机，界面纹丝不动；进播放页按设置的方向转；点关闭自动回竖屏
- [ ] **导入进度**：导入几个大文件，底部出现「正在导入 3/8」，导入期间还能滑动、能点开别的视频
- [ ] 「播完暂停」停在最后一帧后，中间键是否变成 ↺，点一下是否从头播
- [ ] 播完的卡片右下角是否变成勾，且该条目仍在「最近播放」里
- [ ] 退出播放页后，系统亮度是否恢复成进入前的值
- [ ] **锁屏卡片**：播放中锁屏，是否显示封面 + 文件名 + 进度条；锁屏上点暂停/±10 秒/拖进度是否都生效；控制中心里同样能操作
- [ ] **耳机与打断**：AirPods 双击是否切下一集、三击是否回上一集；拔耳机是否自动暂停；来电话结束后是否自动续播
- [ ] 玻璃在真实照片、真实视频上的观感（模拟器只有测试色块）
- [ ] 长按倍速提示的位置与大小是否合适
- [ ] **顶栏搜索**：点左上放大镜 → 键盘弹起跟手吗；输入关键词能否跨文件夹搜到；点「取消」网格是否立刻恢复；长文件夹名在顶栏的省略位置顺不顺眼
- [ ] **长按浮起**：按住卡片/文件夹，放大 + 亮边 + 弹簧落定的手感是否"被拎起来"；松手/点空白时回位是否干脆；菜单有没有压到卡片
- [ ] **设置**：一级菜单只剩图标 + 名称 + 箭头，四行看起来会不会太空；长按倍速那个数值胶囊点开是否还能选四档
- [ ] 关于页版本号显示 `0.0.2`（不带括号）

**P1 · 系统集成**（能力已经具备，只差接线）

- ~~锁屏 / 控制中心媒体控制~~ ✅ 已完成（`227ff27`，`Services/NowPlayingService.swift` 280 行）：上报标题/文件夹/时长/进度/倍速/封面，接收播放、暂停、±10 秒、拖进度、上一集/下一集，另加来电打断恢复与拔耳机暂停。
- 画中画：加 `AVPictureInPictureController`，约 100 行 + delegate。这个 App 最实用的场景就是「看视频回微信」。

**P2 · 小功能补齐**

- 「⋯」菜单的排序只露了名称/日期，`SortKey` 里的「最近播放」「文件大小」没有入口（排序逻辑本身已实现）。
- 存储页加「清空播放记录」「清理失效记录」（`ProgressStore.forget` 目前没人调用）。
- 多选只有删除、移动，缺「批量标记已看」。

**P3 · 工程债**

- `LibraryView.swift` 1279 行、`PlayerScreen.swift` 1112 行、`SettingsView.swift` 503 行，可按「手势 / 浮层 / 控制层」拆成 extension 文件。
- 零单元测试。`Formatters`、`ProgressStore` 的「末尾 15 秒算看完」、四种排序都适合补 XCTest，CI 目前只编译不跑测试。

**P4 · 可选**

- iOS 16 兼容：当前 17.0，要降需给 `MagnifyGesture`、`requestGeometryUpdate` 加可用性判断。
- 原生 `.glassEffect()`：iOS 26 API，需要在 workflow 里 `xcode-select` 到 Xcode 26，部署目标可以仍留 17。
- **图标 v2（实心棱镜）**：现在这张是「空心玻璃三角」，小尺寸下视觉重量偏轻。若要重做，用「以这张为底、改成实心三棱柱并补一条胶片状光带」的局部修正提示词，别整张重生成。换图只需替换 `AppIcon.appiconset/icon-1024.png`（1024×1024、无 alpha）。

### 6.2 已决策不做（别再提）

| 项 | 原因 |
|---|---|
| ~~搜索框~~ | 原来判断「视频不多，加了是噪音」；2026-11-12 改主意，顶栏左侧已加搜索（跨库按文件名） |
| 字幕 / 音轨切换 | AVPlayer 对 mkv 内封字幕基本无解，做出来是「有的能用有的不能」 |
| 海报墙 / 收藏 / 标签 / 评分 | 文件夹层级够用 |
| 局域网传输 | 用「文件」App 或访达共享，Documents 本身就是可见目录 |
| 抓帧存相册 | 曾做过，按需求删了，`FrameGrabber` 和相册写权限都已移除 |
| 白色液态玻璃 | 见第 5 节第 5 条，算术上不成立 |

### 6.3 还没定的小事

- **版本号策略**：2026-11-12 起升到 **0.0.2**（`MARKETING_VERSION: 0.0.2` / `CURRENT_PROJECT_VERSION: 002`），关于页只显示版本号、不显示构建号。以后每批功能改完就升一位。
- **列表循环下播完是否自动标已看**：现在的实现是「播完就打勾」（单集循环除外）。如果你习惯挂着循环当背景放，可能会积累一堆勾，需要改成只在「播完暂停」时标记。
- **菜单尺寸**：宽 200 / 行高 44，一直没确认是否偏小。
- **长按放大比例**：现在是 1.09 + 白 28% 亮边。觉得不够就上 1.12（列间距 12pt 还放得下），觉得晃眼回 1.06；亮边可 18%–40% 之间调。都只改 `LibraryView.liftScale` 与 `Cards.swift` 里那两个常量。
- **搜索范围**：现在跨整个资料库。如果更想「只在当前文件夹里搜」，改 `searchResults` 取 `library.items` 即可。

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
| 某张截图在 `ci-shots` 里但没有 base64 | contents API 只对 **< 1MB** 的文件内联返回；超过就改用 `GET /repos/:o/:r/git/blobs/<sha>`（先查 contents 拿 sha） |
| 缩略图顶部出现绿色横条 | `DebugSeed` 重写示例视频时，缩略图生成器读到了写了一半的文件（半截 H.264）。CI 偶发，重跑即恢复；真机正常导入是先拷完再刷新，一般碰不到 |
| 某一步截图继承了上一步的状态 | 示例视频与设置项都会持久化在模拟器里。比如 `-screen list` 会把「列表模式」写进 UserDefaults，后面的截图就都是列表。**截图顺序要留意，默认网格的截图放在 list 之前** |

**界面**

| 现象 | 原因 / 处理 |
|---|---|
| 缩略图超出卡片 | `ThumbnailView` 只给了 width 没给 height，加 `size` 参数宽高锁死，`clipped()` 要放在 `clipShape()` 之前 |
| 换了 `UIVisualEffectView` 参数外观却不变 | 用 `UIViewRepresentable` 包它是真实子视图，会盖住同层的 SwiftUI 染色。这条路走不通，别浪费时间 |
| 玻璃调透明没效果 | 纯黑底没有内容可透，见第 5 节第 3 条 |
| 长按 2× 松手不复原 | `onLongPressGesture(perform:)` 与松手顺序不定，改成 `onPressingChanged` 自己计时 + 令牌 |
| 边加速边跳进度 | 长按加速中手指移动要立刻 `endBoost()` 再进 seek，两个手势不能同时生效 |
| 方向锁只管播放页 | 播放页曾用 `fullScreenCover`，模态有独立方向策略。改成同层 `.overlay` |
| 进/出播放页时转屏没反应 | `requestGeometryUpdate` 必须丢到下一个 runloop（`DispatchQueue.main.async`）执行，当帧视图还没布局完，系统会直接忽略这次请求 |
| 换了图标，桌面还是旧的 | iOS 会缓存桌面图标。**先重启手机**；不要用卸载来解决（卸载会清空 `Documents`，视频全没）。必须重装的话，先打开「文件」App 把视频拷到「我的 iPhone」根目录，装完再拷回 |
| 播放列表里当前视频被甩到末尾 | `PlayerScreen(queue:)` 每次重算，进播放页时要冻结队列到 `playingQueue` |
| 长按后两张卡叠着，边缘发虚 | 原卡没让位。浮层出现时给原卡 `.opacity(0)`，只留空位 |
| 长按浮起"看不出被选中" | 暗底上黑影无效。必须加 1pt 白 28% 亮边，配合 1.09 放大才成立 |
| 长按菜单贴在卡片上 | 锚点用了原始 frame。放大后的视觉边缘更大，要用 `liftedRect()` 换算再 +8 |
| 长按倍速的数字旁边有上下箭头 | 那是 `pickerStyle(.menu)` 自带的，去不掉。换成 `Menu` + 自绘胶囊 label |
| 设置一级菜单右侧摘要挤掉标题 | 已经整块删掉了（`summary(for:)`），别再往回加 |

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

**现在要装哪一版**

Actions 里最新一次绿的 run（截至 2026-11-12 22:30 是 `43234223189`）→ 页面底部 Artifacts → `LocalPlayer-unsigned-ipa`（是 zip，解压后得到 `LocalPlayer.ipa`）。

- artifact **30 天自动过期**，要留档就下到本地。
- 只要 bundle id 不变，覆盖安装就能保住视频与进度；不需要先卸载。
- 当前版本 **0.0.2**（构建号 002），关于页只显示 `0.0.2`、不显示括号里的构建号。

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
