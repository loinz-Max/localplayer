# 交接文档 · 本地播放器（LocalPlayer）

> 最后更新：2026-11-11 20:40
> 当前状态：**界面已按原型重写完成；已在 GitHub Actions 上编译通过并产出真实截图与未签名 ipa；等待真机验证。**
> 仓库：<https://github.com/loinz-Max/localplayer>（2026-11-11 迁自旧仓库 `hayatlia58-blip/localplayer`）

---

## 一、现在处于哪一步

| 阶段 | 状态 |
|---|---|
| 界面原型（网页版 10 屏，可点可看） | ✅ 完成，定稿 |
| SwiftUI 按原型重写 | ✅ 完成，已编译通过 |
| 模拟器截图校对视觉 | ✅ 完成（run `43018730340`，6 张图在 `ci-shots` 分支） |
| 真机安装试用 | ⏳ 待做 |
| 文档同步（README / DESIGN.md） | ✅ 完成（v0.3，2026-11-11） |

**原型文件**：`preview/ui-v3.html`（直接双击用浏览器打开；加 `?only=3` 只看第 4 屏）

**当前可用的构建**：run `43018730340`（commit `977e768`），模拟器与 ipa 两个 job 均 success。截图自动推到 `ci-shots` 分支（新仓库已把 Workflow permissions 设为 Read and write，这条链路现在是通的）。

### 视觉校对结论（2026-11-11）

- `02-home` / `03-folder` / `04-player` / `05-settings` / `01-empty`：与原型一致，无遮挡错位。
- `06-player-landscape`：截图里控件侧躺 —— 是 `simctl io screenshot` 只拍竖屏 buffer 的已知现象，**不是布局问题**，真机仍需确认三块是否真等高。

---

## 二、本次改动做完了什么

### 设计系统
- `Support/Palette.swift`：换成原型色板（背景 `#0A0A0B`、系统蓝 `#0A84FF`、三级文字灰阶、`#FF453A` 危险色）。
- `Support/Glass.swift`：**四层玻璃配方**（`.ultraThinMaterial` → 渐变染色 → 0.75pt 上亮下暗描边 → 外投影）。三种预设：`.control`（按钮/胶囊）、`.panel`（菜单/抽屉）、`.subtle`。
  - 用法：`.glass(Circle())` / `.glass(cornerRadius: 20)`。
  - **注意**：没有用 iOS 26 的 `glassEffect`。原因是它需要 Xcode 26 工具链，而 CI 跑在 `macos-15` 上不稳定；我们的原型本来就是自定义暗色玻璃，用 Material 能 1:1 还原，部署目标仍是 iOS 17。

### 资料库页（`Views/LibraryView.swift`）
- 顶栏：左齿轮、中间 17pt 标题、右侧导入 + ⋯，四个 36pt 圆键，高 54，左右 16。
- 双列网格，卡片间距 18/12；缩略图 16:9、圆角 12；标题 15pt/600 单行；副标题 `时长 · 体积`（时长异步从 AVAsset 读，带缓存）。
- 缩略图右下角 22pt 已看角标（`.ultraThinMaterial` + 白描边）；手动标记后进度条自动隐藏。
- **长按菜单**（`Views/LibraryMenus.swift` 的 `CardMenu`）：锚定被长按卡片的左下角，宽度 174（= 卡片宽度），圆角 18，行高 42；顶部只有一行 12.5pt 文件名；「标记已看 / 重命名」一组，「删除」红色单独一组。
  - 遮罩 38% 压暗，**被长按的卡片浮在遮罩之上**（重画一份在原位置）。
  - 卡片在屏幕下半部分时菜单自动翻到上方。
- 导入菜单（200 宽，白圆底图标）与「⋯」菜单（200 宽）：新建文件夹 / 排序三选一（最近播放·名称·添加日期）/ 升序降序 / 刷新缩略图。
- 文件夹以卡片形式排在视频前面（原型里没有文件夹，为了能进得去，做成了第一列卡片）。
- 重命名**真的改磁盘文件名**，并把播放记录/已看标记迁移到新 id；失败（同名）会提示。

### 播放页（`Views/PlayerScreen.swift` + `Views/PlayerPanels.swift`）
- 点屏唤出控件，播放中 4 秒淡出，暂停常驻。
- 竖屏：无底进度条（4pt，两端 已播 / 剩余）+ 运输胶囊（50 高）+ 两个 50 圆键。
- 横屏：**三个功能区高度统一 50**、圆角 25、间距 12、贴边 16 —— 运输胶囊 / 进度条胶囊（轨道+时间都装在里面）/ 列表与设置两个圆键。
- 右侧两个抽屉：播放列表（竖屏 264 / 横屏 320，当前项蓝框 + 波形图标）、播放设置（倍速 −/+ 步进 0.25、模式三选一、画面比例三选一、屏幕常亮）。
- **抽屉展开时整层控件收起**（进度条、运输键、右上角按钮全部不渲染），只剩画面 + 抽屉。
- **倍速与模式只在本次播放有效**：存在 `PlayerScreen` 这一层，切集不丢，退出播放页即丢。
- 右上角圆形键：抓当前帧存相册（`Support/FrameGrabber.swift`，需要 `NSPhotoLibraryAddUsageDescription`，已加到 Info.plist）。
- 手势保留：左右滑调进度、左半屏上下滑亮度、右半屏音量、长按 2× 快进、双击左右 10 秒。

### 播放逻辑
- 播放模式：单集循环 / 列表循环（到底回到第一个）/ 播完暂停。
- 已移除：画中画（`PiPManager.swift` 已删除）、音轨菜单、整条音轨选择逻辑。

### 工程 / CI
- `.github/workflows/ios-ipa.yml` 加了两个东西：
  1. **编译失败时把 `error:` 行做成 annotation**，这样不用登录也能在 Checks 里看到报错原文。
  2. **把模拟器截图强推到一个 `ci-shots` 分支**，方便直接 `raw.githubusercontent.com/.../ci-shots/02-home.png` 看图。
- `DebugSeed` 补了 4 段根目录示例视频，首页截图能看到「文件夹卡片 + 视频网格」。

---

## 三、接下来要做的（按优先级）

### P0 · 必须先做
1. **真机装一次**：下载 `LocalPlayer-unsigned.ipa`，用 Sideloadly 签名装机（免费账号 7 天有效），确认：
   - 相册/文件导入 → 网格出现缩略图
   - 长按菜单三项都能用
   - **横屏播放：三块功能区是否真的等高**（模拟器截图看不出）
   - 两个抽屉、截图存相册、长按 2×、双击 ±10 秒不抢事件
2. **重命名交互确认**：现在是「改磁盘文件名」。如果想改成「只改显示名」（更安全，不会因为同名失败），需要加一个 `displayNames` 字典到 UserDefaults，改 `VideoItem.displayName` 的取值来源。

### P1 · 收尾
3. ~~更新 README.md / DESIGN.md~~ ✅ 2026-11-11 已完成
4. ~~删掉 `DebugSeed.seedProgressIfNeeded()` 的伪数据~~ ✅ 已完成
5. ~~清理 `.ci/`~~ — 该目录在交接包里已不存在
6. 删掉 `preview/shots/` 里 4 张旧原型图（可选，只是体积）

### P2 · 以后想加再说
7. ~~排序里补「文件大小」~~ ✅ 2026-11-11 已完成（排序变四选一）
8. ~~播放设置里的「防误触 / 自动隐藏时长」~~ ✅ 已完成；**「锁定方向」仍未做**
9. ~~文件夹重命名 / 删除~~ ✅ 已完成（重命名**只改显示名**，磁盘目录名不动）
10. ~~长按菜单加「移到其他文件夹」~~ ✅ 已完成（`MoveFolderSheet`，含层级缩进与「当前」标记）

### 2026-11-11 晚追加的改动

- 排序新增「文件大小」（同大小按名称排）
- 播放设置新增「自动隐藏」2/4/6 秒（存 `AppSettings.autoHideDelay`）与「防误触」（锁屏后长按 1 秒解除）
- 文件夹长按菜单：重命名（显示名，存 `folder.displayNames.v1`）、删除（递归删目录 + 先清里面视频的进度记录）
- 视频长按菜单新增「移到文件夹」，移动后把进度/已看迁到新 ID
- 顺手修了 `ts`/`m2ts` 被误标为「可播」的问题

---

## 四、怎么继续开发

### 方式 A：本地 Xcode（推荐，改一次看一次）
```bash
brew install xcodegen
cd LocalPlayer
xcodegen generate          # 生成 LocalPlayer.xcodeproj
open LocalPlayer.xcodeproj # 选自己的 iPhone，⌘R
```
- 需要 macOS + Xcode 15 以上（部署目标 iOS 17）。
- `project.yml` 是工程描述文件，**改了文件增删要重新 `xcodegen generate`**。

### 方式 B：GitHub Actions 云端编译（不用 Mac）
- push 到 `main` 自动触发；也可以在 Actions 页面手动 Run workflow。
- 产出两个 artifact：`simulator-screenshots`（截图）、`LocalPlayer-unsigned-ipa`（装机用 ipa）。
- 截图还会自动推到 `ci-shots` 分支，网页上直接能看。

### 换电脑 / 换 GitHub 账号
1. 解压这个 zip 到新电脑。
2. 当前 `origin` 指向 `https://github.com/loinz-Max/localplayer.git`，本机凭据由 Git Credential Manager 管理（已存 `loinz-Max`）。换账号时先清掉旧凭据：Windows「凭据管理器 → Windows 凭据」删掉 `git:https://github.com`，再 push 会重新弹窗登录。
3. 如果沿用旧仓库：`git remote set-url origin <新仓库地址>`；如果是新账号新建仓库：
   ```bash
   cd LocalPlayer
   rm -rf .git                 # 想丢掉旧历史才这么做，否则跳过
   git init && git add -A && git commit -m "init"
   git remote add origin https://github.com/<新账号>/<新仓库>.git
   git push -u origin main
   ```
4. **新仓库第一次跑 Actions 要注意**：Settings → Actions → General → Workflow permissions 选 **Read and write**，否则「把截图推到 ci-shots 分支」那步会失败（不影响编译，只是看不到截图）。
5. 想换 bundle id：改 `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER`。

---

## 五、文件地图

```
LocalPlayer/
├─ project.yml                      XcodeGen 工程描述（部署目标 iOS 17.0）
├─ Info.plist                       含相册读取 + 相册写入两条用途说明
├─ .github/workflows/ios-ipa.yml    云端编译 + 模拟器截图 + 失败取错误
├─ preview/ui-v3.html               ★ 界面原型（10 屏，唯一的设计真相）
├─ scripts/dev.sh                   本地构建小脚本
└─ LocalPlayer/
   ├─ App/LocalPlayerApp.swift      入口
   ├─ Models/VideoItem.swift        VideoItem / SortKey / PlayMode
   ├─ Player/
   │  ├─ PlayerModel.swift          AVPlayer 封装（已去掉音轨）
   │  └─ VideoSurface.swift         AVPlayerLayer 包装
   ├─ Services/
   │  ├─ AppSettings.swift          默认倍速 / 播放模式 / 排序 / 续播
   │  ├─ LibraryStore.swift         扫描、导入、删除、重命名
   │  ├─ ProgressStore.swift        进度 + 最近播放顺序 + 已看标记
   │  ├─ ThumbnailLoader.swift      缩略图缓存 + 时长缓存
   │  └─ PhotoImporter.swift        相册导入
   ├─ Support/
   │  ├─ Palette.swift              色板
   │  ├─ Glass.swift                ★ 四层玻璃配方 + 圆键
   │  ├─ FrameGrabber.swift         抓帧存相册
   │  ├─ Formatters.swift / ScreenBrightness.swift / SystemVolume.swift
   │  └─ DebugSeed.swift            仅 Debug：生成示例视频
   └─ Views/
      ├─ LibraryView.swift          资料库页（网格 + 长按 + 弹窗）
      ├─ LibraryMenus.swift         三个菜单的实现
      ├─ Cards.swift                卡片 / 角标 / 缩略图
      ├─ PlayerScreen.swift         播放页（控制层 + 手势 + 抽屉调度）
      ├─ PlayerPanels.swift         两个抽屉
      └─ SettingsView.swift         设置页
```

---

## 六、待你拍板的两件事

1. **重命名**：改磁盘文件名（现状）还是只改显示名？
2. **弹窗尺寸**：200 宽 / 44 行高 是否偏小？（原型阶段问过一次，你还没回）
