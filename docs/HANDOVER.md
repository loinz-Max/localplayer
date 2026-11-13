# 交接文档 · 幕间（工程名 LocalPlayer）

> 最后更新：2026-11-13 17:30
> 仓库：<https://github.com/loinz-Max/localplayer>（public，可自由 clone）
> 当前版本：**0.0.7**（构建号 007，已发 Release）｜部署目标 iOS 17.0｜bundle id `com.loinzmax.localplayer`（**永不改动**）
> 最新提交：`4a88c2c`（README 产品化）← `a7e2122`（上线版结构整理）← `24354d6`（去腐）
> 快照 tag：`snapshot-pre-release-cleanup`（结构整理前全量，含旧版交接文档 / 验收存档 / preview 原型）；历史 tag `snapshot-2026-11-13-0.0.7` 及更早

一句话：这是一个只给自己用的 iOS 本地视频播放器，SwiftUI + AVPlayer，视频只躺在 App 的 `Documents` 里，不联网、不登录、不上传。**仓库已完成「上线化」：主页是产品展示页，开发内容全部收在 `docs/`。**

---

## 0. 项目进度

### 0.1 六十秒看懂

| 你关心的事 | 答案 |
|---|---|
| 现在能日常用吗 | **能。0.0.3 于 2026-11-13 整批真机验收通过**；0.0.4–0.0.7 的增量改动装机使用中，其中 0.0.6 / 0.0.7 的单项回归还没专门过一遍（见 6.1 P0） |
| 它叫什么 | 桌面名 **幕间**（Interlude），工程名/仓库名/bundle id 仍是 `LocalPlayer` |
| 功能齐了吗 | 齐。画中画、锁屏遥控、播完连播都有；仓库已按上线版整理完毕 |
| 需要 Mac 吗 | 不需要。编译和出包全在 GitHub Actions |
| 需要开发者账号吗 | 不需要。免费 Apple ID + 爱思助手自签，7 天有效 |
| 改完怎么看到效果 | push 到 `main`，Actions 自动编译 + 出 20 张截图 + 出 ipa，约 10 分钟 |
| 最大的坑是什么 | 玻璃在纯黑底上没东西可透，调透明度救不回来（第 5 节第 3 条） |

### 0.2 迭代记录

| # | 交付内容 | 提交 | 状态 |
|---|---|---|---|
| 1 | **0.0.1 基线**：资料库网格/列表、多选、长按菜单、播放页双抽屉、拖动小窗预览、进度角标、设置四级菜单、版本号落地 | `c38c45e` | ✅ 已装真机 |
| 2 | **播放收尾**：播完可重播、播完自动标已看、退出恢复系统亮度 | `8cf6ffa` | ✅ 已验 |
| 3 | **观感与导入**：玻璃调透一档 + 描边提亮、背景白雾、提示统一 HUD、导入后台化 | `47501e6` → `140addb` | ✅ 已验 |
| 4 | **仓库整理（第一轮）**：`.gitignore` 修正、文档对齐代码、验收清单归档 | `3ae236a` → `a34bc1c` | ✅ 文档类 |
| 5 | **品牌**：桌面名「幕间」+ 关于页 `INTERLUDE`；深底玻璃棱镜图标 | `d1fa741`、`d24e81c` | ✅ 已验 |
| 6 | **方向**：方向设置只作用于播放页，退出自动转回 | `3e3c7b4` | ✅ 已验 |
| 7 | **系统集成**：锁屏 / 控制中心 / AirPods / 车机的正在播放与遥控（`Services/NowPlayingService.swift`） | `227ff27` | ✅ 已验 |
| 8 | **顶栏**：左侧加搜索、标题独立居中、根目录标题 `Interlude` | `abe9091`、`c1b08c8` | ✅ 已验 |
| 9 | **细节**：长按倍速数值胶囊、移除「资料库排版」、版本号只显示主版本 | `d8ddc63`、`277663c` | ✅ 已验 |
| 10 | **长按浮起**：原位留空 + 放大 1.09 + 亮边 + 散投影 + 弹簧 | `9549d99` → `43715c9` | ✅ 已验 |
| 11 | **设置精简**：一级菜单去掉右侧状态摘要 | `0900731` | ✅ 已验 |
| 12 | **转屏幕布**：转屏前拉黑幕、旋转发生在幕后（`Support/OrientationCurtain.swift`） | `8ce069f` | ✅ 已验 |
| 13 | **幕布提示去卡片**：小手机与文字直接嵌进黑幕 | `39e5ab0` | ✅ 已验（0.0.4） |
| 14 | **画中画 + 自动连播 + 跳过片头 + 冷启动一闪**（`Support/PiPService.swift`、`Support/LaunchFlash.swift`） | `e334d78` + `df9bcdc` | ✅ 已验（0.0.5） |
| 15 | **真机五项修正**：亮度手势误触加速修复、幕布提速增实、抽屉/菜单收窄、**移除跳过片头** | `f735830` + `667b8c3` | 🟡 已装机（0.0.6） |
| 16 | **外部接管自动解防误触**：锁屏/控制中心/耳机/车机遥控、来电打断、拔耳机，先解锁再执行 | `6409aad` → `a621e1e` | 🟡 已发版（0.0.7），单项真机回归待做 |
| 17 | **去腐**：删 7 处死代码，文档纠 11 处 | `24354d6` | ✅ 无行为变化 |
| 18 | **上线版结构整理**：删 `preview/` 原型、验收存档、旧交接文档；新增精简 `docs/DEVELOPMENT.md`；修 `dev.sh` bundle id；删 `Info.plist` 相册权限串 | `a7e2122` | ✅ 无行为变化 |
| 19 | **产品化收尾**：README 改纯产品展示页；6 个 Release 说明改写为 diff 式（相对上一版的增删）；本文档以最新状态回归 `docs/` | `4a88c2c` + 本轮 | ✅ |

### 0.3 距离「完整」还差什么

1. **P0：真机把 0.0.6 / 0.0.7 的增量过一遍**（清单见 6.1）。
2. **P2：清空播放记录**入口（存储页）——已看勾和进度会积累，偶尔想清零。
3. **P2：最近播放视图**——`ProgressStore.lastPlayed / order` 字段已预留（只写不读）。
4. P3 工程债：拆 1000+ 行视图、补单元测试。做之前先想值不值。

---

## 1. 换设备接手：四步

```bash
git clone https://github.com/loinz-Max/localplayer.git
cd localplayer
git config user.name  "hayatlia58-blip"
git config user.email "你的 GitHub 邮箱"
```

1. **读三份文档**：本文件（进度 + 坑）+ `docs/DESIGN.md`（视觉规格）+ `docs/DEVELOPMENT.md`（构建 / 装机 / 发版 / 排障）。
2. **看当前界面**：`ci-shots` 分支有 20 张模拟器实拍图 → <https://github.com/loinz-Max/localplayer/tree/ci-shots>
3. **要改代码**：`hayatlia58-blip` 已是协作者、有 push 权限，改完 `git push origin main`。
4. **在 WorkBuddy 里接着干**，直接说：

   > 读 localplayer 仓库的 docs/HANDOVER.md、docs/DESIGN.md 和 docs/DEVELOPMENT.md，先告诉我现在的进度和待办，别急着改代码。

> **协作者权限已就绪**：`hayatlia58-blip` 对仓库有 write 权限，可直接 push `main`。
> 换设备时注意：WorkBuddy 的会话记忆不跨设备。**凡是要留下的信息都在本文件里**，别指望记忆。
> Windows 本机凭据存在「凭据管理器 → `git:https://github.com`」，换账号要先删这条（否则 403）。

### 1.1 换机器时，把下面这段直接粘进新会话

```
我要接手一个 iOS 项目，先别改代码。

仓库：https://github.com/loinz-Max/localplayer （public；我的账号 hayatlia58-blip 已是协作者，有 push 权限）

请依次做：
1. clone 到当前工作区（已经有 localplayer 目录就跳过）
2. 读 docs/HANDOVER.md、docs/DESIGN.md、docs/DEVELOPMENT.md
3. 用 10 行以内汇报：现在到哪一步、哪些改动还没过真机验收、你建议下一步做什么
4. 然后停下等我说方向

背景（不用再问我）：
- SwiftUI + AVPlayer 的 iOS 本地视频播放器「幕间」，零第三方依赖、不联网，部署目标 iOS 17，当前版本 0.0.7。
- 没有 Mac：push 到 main 由 GitHub Actions 编译、出 20 张模拟器截图（ci-shots 分支）、出未签名 ipa。
- 装机用爱思助手签名（免费证书 7 天）；bundle id 不要改，改了等于换新 App、视频和进度全丢。
- README 是产品展示页，别往里加开发内容；开发文档都在 docs/。
- push 报 502 / schannel 错误时，改用 node scripts/push-api.js。
```

---

## 2. 环境与工具链

### 2.1 没有 Mac 怎么编译

push 到 `main` 自动跑 `.github/workflows/ios-ipa.yml`：

| Job | 产出 | 在哪拿 |
|---|---|---|
| 打包未签名 ipa | `LocalPlayer-unsigned-ipa` | run 页面底部 Artifacts（30 天过期） |
| 模拟器截图 | 20 张 PNG | 推到 `ci-shots` 分支 |

- 编译错误会写进 GitHub annotation，不用翻日志。
- Fork 后第一次跑：Settings → Actions → General → Workflow permissions 选 **Read and write**，否则推 `ci-shots` 失败。
- **Release 是永久存档**：v0.0.2–v0.0.7 每版都有 ipa，说明已写成 diff 式（相对上一版的增删）。

### 2.2 装机（爱思助手签名）

1. 下载 ipa → 爱思「工具箱 → IPA 签名」，填 Apple ID（开了双重认证的用 App 专用密码）。
2. 「设置 → 通用 → VPN 与设备管理」信任证书；iOS 16+ 开「开发者模式」。
3. **免费证书 7 天过期**，重签时 bundle id 不变即可**覆盖安装**，视频与进度不丢。
4. bundle id 撞车会导致签名失败，当前 `com.loinzmax.localplayer`，别改。

### 2.3 权限与网络

- push 权限三条路：协作者 `hayatlia58-blip` 直接推（现用）；fork + PR；登 owner 账号（账号混用，不推荐）。
- `git push` 报 502 / schannel：用 `node scripts/push-api.js` 走 Git Data API。
- Windows 凭据在「凭据管理器」，换账号先删 `git:https://github.com` 那条。
- 交互式 shell 外取 GitHub token：`export GH_TOKEN=$("C:/Users/Admin-pc/AppData/Local/gh-cli/gh.exe" auth token)`。

---

## 3. 仓库结构（上线版）

```
localplayer/
├─ README.md                     产品展示页（功能 / 截图 / 下载直链 / License）——别往里加开发内容
├─ CHANGELOG.md                  逐版本增删记录（0.0.1–0.0.7）
├─ project.yml                   XcodeGen 工程描述（版本号也在这里改）
├─ Info.plist                    桌面名、文件共享、后台音频、方向声明
├─ .github/workflows/ios-ipa.yml 云端编译 + 截图 + 出包
├─ docs/
│  ├─ HANDOVER.md                本文件（进度 + 坑 + 待办）
│  ├─ DESIGN.md                  视觉与交互规格
│  └─ DEVELOPMENT.md             构建指南（编译 / 装机 / 发版 / 排障）
├─ scripts/
│  ├─ dev.sh                     有 Mac 时一键编译装机
│  ├─ push-api.js                git 通道被代理挡住时的推送兜底
│  ├─ gh-helper.js               查 CI 运行、下载 artifact
│  └─ publish-ipa.js             把 ipa 传成 Release 资产
└─ LocalPlayer/                  29 个 Swift 文件、约 6400 行、零第三方依赖
   ├─ App/          入口、EnvironmentObject 注入、AVAudioSession
   ├─ Models/       VideoItem / SortKey / PlayMode
   ├─ Player/       PlayerModel（AVPlayer 封装）、VideoSurface
   ├─ Services/     LibraryStore / ProgressStore / AppSettings / ImportService / ThumbnailLoader / NowPlayingService
   ├─ Support/      Glass / Palette / HUD / PiP / 方向锁 / 幕布 / 冷启动 / 亮度 / 音量 / 抓帧预览 / DebugSeed
   └─ Views/        Library / Cards / Menus / Player / Panels / Settings / PhotoPicker
```

**改代码前先想清楚落点**：样式进 `Support/`，状态进 `Services/`，纯 UI 进 `Views/`。`GlassStyle` 和 `Palette` 改一处等于全站换肤，别在 View 里硬编码颜色。

**文档约定**：对外形象只动 README（产品页）；一切开发内容写进 `docs/` 三件套；每版改动写进 `CHANGELOG.md` 的「未发布」段，发版时固化并同步成 Release 的 diff 式说明。

---

## 4. 数据与状态

| 数据 | 存哪 | 规则 |
|---|---|---|
| 视频文件 | `Documents/` | **相对路径就是 ID**（`VideoItem.id`），改路径等于换 id |
| 播放进度 | UserDefaults `progress.snapshot.v1` | positions / totals / lastPlayed / order（上限 60 条）/ watched |
| 文件夹显示名 | UserDefaults `folder.displayNames.v1` | 只影响界面，磁盘目录名不动 |
| 设置 | UserDefaults | 键名集中在 `AppSettings.Key`，别再手写字符串 |
| 缩略图 | 内存 NSCache | 取「时长 12%，不早于 3 秒」那一帧，失败退 3 秒 → 首帧 → 占位图 |

迁移规则：

- **视频重命名**必须调 `progress.renamePath(from:to:)`，否则进度和已看标记丢。
- **移动视频**同理，id 变了必须迁移。
- **文件夹重命名只改显示名**，真改目录名会让里面所有视频 id 失效。
- 「播完」的语义是 `watched`（打勾），不是清空记录。

---

## 5. 设计硬规则

这些是已经付过学费的决定，改之前先读原因。

1. **原型已删，代码是唯一真相。** 早期 HTML 原型已随结构整理移出仓库（`snapshot-pre-release-cleanup` tag 里还有）。要确认界面长什么样，看 `ci-shots` 分支实拍图。
2. **玻璃是四层**：`ultraThinMaterial` → 渐变染色 → 0.75pt 上亮下暗描边 → 外投影。
3. **纯黑底上玻璃永远是黑的。** 资料库背景顶部那层 2.8% 白雾（`LibraryView.backgroundLayer`）就是干这个的，别当废代码删掉。
4. **降低染色 alpha 必须同步加亮描边**（约 +0.04），否则控件边界会散。
5. **白玻璃方案试过，失败。** 纯黑背景 + 白染色，算术上不成立，别再试。
6. **播放页控件必须暗色染色**，白色染色在亮画面上等于加亮，白图标会糊。
7. **轻提示只有一套**：`Support/HUD.swift` 的 `HUDLabel`，别在页面里另写胶囊。
8. **倍速与播放模式只在本次播放有效**，切集不丢、退出即丢，设置里的是起点值。
9. **防误触是手动锁**：锁上后点屏幕只亮解锁键，没有长按手势。
10. **方向锁生效就不要用 modal**：播放页用同层 `.overlay`，`fullScreenCover` 有独立方向策略会绕开 mask。
11. **不支持格式仍显示在列表**，带警告图标，点开才提示转码。
12. **零第三方依赖，不联网。** 加任何依赖前先想清楚要不要为它维护 CI。
13. **方向：只有播放页能转**，非播放页由 AppDelegate mask 强制竖屏。
14. **长按浮起＝原位留空 + 放大 1.09 + 1pt 白 28% 亮边**，缺一样在近黑底上都看不出来。
15. **改名只动显示名**：`PRODUCT_NAME`、仓库名、bundle id 一律不动，动了等于换新 App，数据全丢。

---

## 6. 待办与已知问题

### 6.1 待办（按优先级）

**P0 · 真机验收 0.0.7**（外部操作 × 防误触，只能真机做）

- [ ] **锁屏按暂停**：播放页锁上防误触 → 锁屏按暂停 → 回到 App，控件应当已经可以直接点
- [ ] **控制中心按暂停**：同样先锁上 → 下拉控制中心按暂停 → 回到 App 防误触已解开
- [ ] **±10 秒 / 拖进度 / 切集同样解锁**
- [ ] **来电也解锁**：锁着时来一通电话，挂断回到 App 防误触已解开
- [ ] **拔耳机也解锁**：锁着时拔掉耳机，回到 App 防误触已解开
- [ ] **没锁的时候行为不变**：不会多闪一下

**P0 · 真机回归 0.0.6**（五项修正）

- [ ] 左侧调亮度不再误触加速；长按加速仍好用（按住 0.28 秒出倍速提示）
- [ ] 幕布更快更实：横握退出播放页黑一下就转，看不到画面被拧
- [ ] 列表抽屉与「⋯」菜单比之前窄一圈，内容不截断
- [ ] 跳过片头已消失（长片开头没有胶囊）
- [ ] 画中画 / 播完自动下一集回归复查没被改坏

**P2 · 小功能补齐**

- 存储页加「清空播放记录」（删除单个视频时 `ProgressStore.forget` 会自动清，缺整体清零入口）。
- 最近播放视图：`lastPlayed` / `order` 只写不读，字段已预留。
- 多选缺「批量标记已看」。

**P3 · 工程债**

- `LibraryView.swift` 1290 行、`PlayerScreen.swift` 1145 行，可按「手势 / 浮层 / 控制层」拆 extension。
- 零单元测试。`Formatters`、`ProgressStore` 的「末尾 15 秒算看完」、两种排序适合补 XCTest。

**P4 · 可选**

- 图标 v2（实心三棱柱 + 胶片光带）的局部修正，别整张重生成。
- 原生 `.glassEffect()`（iOS 26 API）需要换 CI 工具链，暂缓。

### 6.2 已决策不做（别再提）

| 项 | 原因 |
|---|---|
| 排序入口补齐 | 用户决策：名称 / 日期两档就够（0.0.7 已把另两档连代码删了） |
| 字幕 / 音轨切换 | AVPlayer 对内封字幕基本无解 |
| 海报墙 / 收藏 / 标签 / 评分 | 文件夹层级够用 |
| 局域网传输 | 「文件」App 或访达共享即可，不弄脏「不联网」的承诺 |
| 抓帧存相册 | 曾做过，按需求删了，别加回来 |
| 白色液态玻璃 | 见第 5 节第 5 条 |
| 跳过片头 | 0.0.5 做过、0.0.6 移除；将来重做应存成文件级显式记录 |

---

## 7. 踩坑清单（按现象查）

**构建与 CI**

| 现象 | 原因 / 处理 |
|---|---|
| 编译报错但看不到细节 | 看 check-run annotations 或 workflow 的「提取编译错误」步骤 |
| CI 报 runner 分配失败 | macOS runner 容量问题，重新触发 |
| 推 `ci-shots` 失败 | Workflow permissions 不是 Read and write |
| 截图里播放键后面有大白圆 | 不是 UI，是 DebugSeed 示例视频里的移动圆 |
| 横屏截图内容转了 90° | `simctl io screenshot` 只拍竖屏 buffer，布局其实是对的 |
| 某个面板截不到 | `-panel speed\|queue\|lock\|level\|boost` 强制打开 + `-keepChrome 1` |
| 截图继承了上一步的状态 | 示例视频与设置会持久化，默认网格截图要排在 list 之前 |

**界面**

| 现象 | 原因 / 处理 |
|---|---|
| 玻璃调透明没效果 | 纯黑底没有内容可透，见第 5 节第 3 条 |
| 长按 2× 松手不复原 | 用 `onPressingChanged` 自己计时 + 令牌 |
| 边加速边跳进度 | 加速中手指移动要立刻 `endBoost()` 再进 seek |
| 方向锁只管播放页 / 进出播放页转屏没反应 | 播放页用同层 overlay 不用 modal；`requestGeometryUpdate` 丢到下一个 runloop |
| 转屏幕布拉开还能看见画面被拧 | 幕布 hold 必须 > action 延迟 + 系统旋转时长 |
| 换图标桌面还是旧的 | iOS 缓存图标，**重启手机**，不要卸载（卸载清空 `Documents`） |
| 播放列表里当前视频被甩到末尾 | 进播放页要冻结队列到 `playingQueue` |
| 长按后两张卡叠着 / 看不出被选中 / 菜单贴在卡片上 | 原卡 `.opacity(0)` 让位；必须 1.09 放大 + 亮边；锚点用 `liftedRect()` |
| 设置一级菜单右侧摘要挤掉标题 | 已整块删掉，别加回来 |

**文件与数据**

| 现象 | 原因 / 处理 |
|---|---|
| 设置里数得到视频、列表里不显示 | 外部写入路径带 `/private` 前缀，`VideoItem.relativePath` 已做兼容 |
| 从爱思/文件 App 拷完没反应 | `LibraryStore` 监听 Documents + `scenePhase` 重扫 + 下拉刷新 |
| 改名后进度丢了 | 忘了调 `progress.renamePath(from:to:)` |

---

## 8. 发布与验收流程

**改完一次的标准动作**

1. 改代码 → commit（中文一句话）→ `git push origin main`
2. 等 Actions 两个 job 变绿（约 8–12 分钟）
3. 到 `ci-shots` 分支核对截图
4. 下载 ipa → 爱思签名 → 覆盖安装
5. 按第 6.1 节 P0 清单在真机过一遍
6. 有问题记进验收清单，改完再打一轮

**发版**

1. `CHANGELOG.md` 的「未发布」段固化为版本号
2. `project.yml` 同步 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`（三位数递增）
3. `node scripts/publish-ipa.js <ipa路径> <tag> <资产名>` 发 Release
4. **Release 说明写成 diff 式**（相对上一版的增删，分「新增 / 修复 / 观感 / 移除」），不要写成累积功能清单——v0.0.2 起已是这个格式
5. 重要的结构调整打 tag 存档

**当前最新直链**：`https://github.com/loinz-Max/localplayer/releases/download/v0.0.7/LocalPlayer-0.0.7-unsigned.ipa`

---

## 9. 给它加功能前，先问三个问题

1. **这是一个人用的东西吗？** 功能加了就是维护成本。
2. **能不能用系统自带能力？** AVPlayer 已经免费给了 AirPlay、HDR、硬件解码。
3. **截图能不能验证？** 验证不了的改动（导入进度、锁屏、旋转）一定要真机过一遍再算完成。
