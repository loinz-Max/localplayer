# 开发与构建指南

> 界面与视觉规格见 [`DESIGN.md`](DESIGN.md)，逐版本改动见 [`CHANGELOG.md`](../CHANGELOG.md)。
> 本文件只讲怎么构建、怎么发版、怎么排障。

## 1. 从源码构建

### 有 Mac

```bash
brew install xcodegen
xcodegen generate
open LocalPlayer.xcodeproj    # 选自己的 iPhone，⌘R
```

或一键编译 + 装进模拟器 + 带示例视频启动：`bash scripts/dev.sh`。
增删 Swift 文件后要重新 `xcodegen generate`。

### 没有 Mac（本仓库的方式）

推送 `main` 自动触发 [`ios-ipa.yml`](../.github/workflows/ios-ipa.yml)，两个 job 并行：

| Job | 产出 | 在哪拿 |
|---|---|---|
| 打包未签名 ipa | `LocalPlayer-unsigned-ipa` artifact | run 页面底部 Artifacts |
| 模拟器截图 | 20 张 PNG | 推到 `ci-shots` 分支 |

- 编译失败时，错误会写进 GitHub 的 annotation，不用翻日志。
- Fork 后第一次跑：Settings → Actions → General → **Workflow permissions 选 Read and write**，否则推 `ci-shots` 会失败。
- artifact 30 天自动过期，要留档就下载到本地。
- 调试启动参数（仅 Debug）：`-screen home|folder|player|settings|empty`、`-panel queue|speed|lock|level|boost`、`-seedDemo 1`、`-keepChrome 1`、`-landscape 1`，写在 `Support/DebugSeed.swift`。
- 模拟器不支持画中画，`isSupported` 恒 false——CI 截图里看不到画中画按钮是正常的。
- 模拟器 `simctl io screenshot` 只拍竖屏 buffer，横屏截图里控件侧躺是截屏方式的问题，不是布局问题。

## 2. 装机（未签名 ipa + 自签）

1. 下载 ipa → 爱思助手「应用 → 导入 ipa」或 [Sideloadly](https://sideloadly.io) 拖入，填 Apple ID 签名。
2. iPhone「设置 → 通用 → VPN 与设备管理」信任证书；iOS 16+ 开「开发者模式」并重启。
3. **免费证书 7 天过期**，重签时 bundle id 不变即可**覆盖安装**，视频与进度不丢。
4. bundle id `com.loinzmax.localplayer` **永远不改**——改了等于换新 App，`Documents` 里的数据全丢。
5. 换图标后桌面显示旧的：**重启手机**，不要卸载重装。

## 3. 发版流程

1. 改代码 → commit → push `main` → 等 Actions 变绿（约 8–12 分钟）。
2. 到 `ci-shots` 分支核对截图，重点看改动涉及的屏。
3. 同步 `project.yml` 里 `MARKETING_VERSION`（展示版本）与 `CURRENT_PROJECT_VERSION`（构建号，三位数递增）。
4. 打包后发 Release：`node scripts/publish-ipa.js <ipa路径> <tag> <资产名>`，会打印免登录直链。
5. `CHANGELOG.md` 的「未发布」段固化为对应版本号。
6. 重要的结构调整打 tag 存档。

## 4. 仓库工具脚本

| 脚本 | 用途 |
|---|---|
| `dev.sh` | 有 Mac 时一键：生成工程 → 编译 → 装进模拟器 → 带示例视频启动 |
| `gh-helper.js` | 查 CI 运行状态、下载 artifact（`node scripts/gh-helper.js runs\|artifacts <id>\|download <id> <out>`） |
| `publish-ipa.js` | 把 ipa 传成 GitHub Release 资产，得到免登录直链 |
| `push-api.js` | 本机代理挡住 git 通道时，改用 Git Data API 推送的兜底 |

## 5. 排障速查

| 现象 | 原因 / 处理 |
|---|---|
| 编译报错但看不到细节 | 看 check-run 的 annotations 或 workflow 的「提取编译错误」步骤 |
| CI 报 runner 分配失败 | macOS runner 容量问题，重新触发即可 |
| 推 `ci-shots` 失败 | Workflow permissions 不是 Read and write |
| `git push` 报 502 / schannel | 用 `node scripts/push-api.js` 走 Git Data API |
| 改名后进度丢了 | 视频重命名必须调 `progress.renamePath(from:to:)`（路径即 ID） |
| 缩略图超出卡片 | `ThumbnailView` 要 `size` 参数宽高锁死，`clipped()` 放在 `clipShape()` 之前 |
| 转屏幕布拉开时还能看见画面被拧 | 幕布 hold 必须大于 action 延迟 + 系统旋转时长（`Support/OrientationCurtain.swift`） |
| 方向锁不生效 | `requestGeometryUpdate` 要丢到下一个 runloop；播放页不能用 `fullScreenCover`（modal 有独立方向策略） |
| 设置里数得到视频、列表里不显示 | 外部写入路径带 `/private` 前缀，`VideoItem.relativePath` 已做兼容 |

更多设计层面的硬规则（玻璃配方约束、长按浮起参数、防误触策略）见 [`DESIGN.md`](DESIGN.md) 第 2 节与第 5 节。

## 6. 项目进度与交接

当前进度、待办清单、迭代记录与踩坑全集见 [`HANDOVER.md`](HANDOVER.md)——接手开发从它开始，本文件只讲怎么构建与发版。
