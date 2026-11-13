# 幕间 · Interlude

<p align="center">
  <img src="LocalPlayer/Assets.xcassets/AppIcon.appiconset/icon-1024.png" width="120" alt="幕间图标" />
</p>

**一个人的 iOS 本地视频播放器。SwiftUI + AVPlayer，零第三方依赖，不联网、不登录、不上传。**

![version](https://img.shields.io/badge/version-0.0.7-blue)
![platform](https://img.shields.io/badge/iOS-17.0%2B-informational)
![deps](https://img.shields.io/badge/dependencies-0-success)
![CI](https://img.shields.io/github/actions/workflow/status/loinz-Max/localplayer/ios-ipa.yml?label=build)
![license](https://img.shields.io/github/license/loinz-Max/localplayer)

视频只存在 App 的 `Documents` 目录里。没有账号体系、没有统计埋点、没有任何服务器——源码里搜不到一个网络请求。

> **幕间**——两幕之间的黑场，灯暗一下，换一场。

---

## ✨ 功能

### 资料库

- 文件 App / 相册 / 访达文件共享三种导入，**后台导入**带进度胶囊，导完汇总说明
- 文件夹浏览、新建、重命名（只改显示名不动磁盘）、删除（有确认）
- 顶栏搜索：跨整个资料库按文件名找，结果标出所在文件夹
- 长按视频：标记已看、重命名（进度与已看标记随之迁移）、移到文件夹、删除
- 缩略图取「时长 12%、不早于 3 秒」那一帧——自动避开片头台标和广告

### 播放

- 断点续播；播放模式：列表循环 / 单集循环 / 播完暂停（播完自动标已看）
- **播完自动下一集**：设置开关（默认关），追剧模式
- **画中画**：播放页一键进系统小窗；小窗「展开」带进度回到播放页，「关闭」则暂停收尾
- 倍速五档直选 + 长按倍速（1.5–3× 可配）；画面比例适应 / 填充 / 拉伸
- 手势：横滑调进度（带目标帧预览）、左滑亮度右滑音量、长按加速、双击 ±10 秒、双指捏合切比例
- 防误触锁（锁屏、控制中心、来电、拔耳机等外部操作都会自动解锁）、控件自动隐藏可调、屏幕常亮

### 系统集成

- **锁屏 / 控制中心 / AirPods / 车机「正在播放」**：封面、进度条、±10 秒、拖进度、切集
- 来电打断后自动续播，拔耳机自动暂停
- 后台音频：切出去声音继续

### 观感

- 自定义四层液态玻璃控件体系，近黑底上自有一套稳定的层次
- **转屏幕布**：进出播放页的旋转发生在黑幕后面，配「竖屏观看 / 横屏观看」小动画——只在真的会转屏时出现
- 冷启动棱镜 logo 一闪（约 1 秒），灯亮之前的一瞬，不是开屏广告

---

## 📱 界面

截图来自 GitHub Actions 模拟器实拍（见 [`ci-shots`](https://github.com/loinz-Max/localplayer/tree/ci-shots) 分支）：

| 资料库 | 播放页 | 横屏播放 |
|:---:|:---:|:---:|
| ![资料库](https://raw.githubusercontent.com/loinz-Max/localplayer/ci-shots/03-folder.png) | ![播放页](https://raw.githubusercontent.com/loinz-Max/localplayer/ci-shots/04-player.png) | ![横屏](https://raw.githubusercontent.com/loinz-Max/localplayer/ci-shots/06-player-landscape.png) |

更多场景（搜索 / 播放列表 / 设置页 / 长按菜单）也在 `ci-shots` 分支里。

---

## 📥 下载

**[v0.0.7 · LocalPlayer-0.0.7-unsigned.ipa](https://github.com/loinz-Max/localplayer/releases/download/v0.0.7/LocalPlayer-0.0.7-unsigned.ipa)**（2.10 MB）

- 需要 iOS 17.0 或更高版本
- ipa 未签名：用爱思助手 / [Sideloadly](https://sideloadly.io) 等工具填自己的 Apple ID 签名后安装
- 支持 mp4 / mov / m4v / 3gp / mpg 等系统解码器能播的格式

---

## 📄 License

[MIT](LICENSE) © 2026 loinz-Max
