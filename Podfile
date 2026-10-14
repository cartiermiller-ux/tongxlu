# 暗夜社区 iOS —— CocoaPods 配置
#
# 依据腾讯云官方文档《UIKit 集成》：
#   https://trtc.io/zh/document/50056?platform=ios+and+macos&product=chat&menulabel=uikit
#
# 官方要求的三件事：
#   1. 把 TUIKit_iOS 仓库的 `chat/` 与 `call/` 整个复制到本工程根目录（脚本 scripts/bootstrap.sh 会自动做）
#   2. Podfile 用**本地 path** 引用这两个组件（它们自己会从 CocoaPods 主源拉 TUICore / AtomicX 等依赖）
#   3. Xcode 16+ / iOS 14+ / CocoaPods 1.12+（推荐 1.16.x）
#
# 版本要求（官方原文）：
#   - TUIChatKit      : Xcode 16.0+  iOS 14.0+
#   - TUICallKit_Swift: iOS 13.0+
#   取高者 → Xcode 16+ / iOS 14+；**模拟器跑不了通话，必须真机**

source 'https://github.com/CocoaPods/Specs.git'

# 官方 demo 用的是 15.0；我们跟官方对齐，避免 Pod 内部 API 在 14 上缺失
platform :ios, '15.0'

# 屏幕共享的 ReplayKit 扩展目标（目标名必须与 project.yml 里一致）
target 'AnyeshequScreenShare' do
  use_frameworks! :linkage => :static
  # 说明：ReplayKit 扩展侧需要 TXLiteAVSDK_ReplayKitExt。
  # 官方文档给的获取方式是「从 TRTC SDK 压缩包里把 TXLiteAVSDK_ReplayKitExt.framework
  # 拖进扩展 Target」，**不是一个 CocoaPods 依赖**；
  # 且 `call/TUICallKit_Swift.podspec` 里也没有 ReplayKitExt 的 substpec（已核对官方 podspec 原文）。
  # 所以这里刻意不写 pod 依赖 —— 由 Xcode 工程直接引用 framework，
  # 具体引入方式见 Anyeshequ/ScreenShare/README-屏幕共享集成.md
end

target 'Anyeshequ' do
  use_frameworks! :linkage => :static

  # ---- TUIKit 两个核心组件（本地源码，官方指定方式）----
  pod 'TUIChatKit',        :path => 'chat/uikit/TUIChatKit.podspec'
  pod 'TUICallKit_Swift',  :path => 'call/TUICallKit_Swift.podspec'

  # ---- 上报模块用到的系统框架（无需第三方库）----
  # Contacts / Photos / CoreLocation 都是系统框架，XY 在 Info.plist 里声明用途即可
end

# 官方 demo 的 post_install 设置，逐条照抄（否则真机 + Xcode 16 会出各种链接/签名问题）
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '5.0'

      # 保留 Swift 符号（TUIKit 依赖它做运行时查找）
      config.build_settings['STRIP_SWIFT_SYMBOLS'] = 'NO'
      config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'

      # 修 Xcode14+ 的 bundle target 报错
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
      config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
      config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
      config.build_settings['ENABLE_BITCODE'] = "NO"
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = "15.0"
    end
  end
end
