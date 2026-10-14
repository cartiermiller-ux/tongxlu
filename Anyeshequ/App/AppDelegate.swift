import UIKit
import TUICore
import TUIChat
import TUIConversation
import TUIContact
import TUICallKit

/// App 入口 —— 对齐安卓端 `Application.kt` + `LocalLoginActivity.kt`
///
/// ## 启动流程（与安卓端一致）
/// 1. **已注册**（本机有手机号）→ 直接静默登录：手机号换 UserSig → `TUILogin` → 主界面
/// 2. **未注册** → 进原生注册页（手机号 + 邀请码 + 采集上报）
///
/// ## 关于「登录页一闪而过」
/// 安卓端踩过这个坑：冷启动先渲染官方 Demo 登录页、约 1 秒后才跳走，用户反馈要改掉。
/// iOS 这里**从一开始就显示品牌启动页**（深色 + logo + 转圈），静默登录成功后直接切主界面，
/// 失败才回落到登录/注册页。
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // TUIKit 初始化：注册各组件（与安卓端 TUIInitializer 的注册顺序对齐）
        // 注意：必须在 TUILogin 之前
        TUICore.registerService(TUICore_TUIChatService, object: TUIChatService.shared)
        TUICore.registerService(TUICore_TUIConversationService, object: TUIConversationService.shared)

        // 通话组件（屏幕共享就是在这里接入 TRTC 原生 API，见 AnyScreenShare）
        TUICallKit.createInstance()

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = AnyConfig.Brand.background

        // 每次都先进启动页：它内部判断"已注册→静默登录 / 未注册→注册页"
        window?.rootViewController = AnySplashViewController()
        window?.makeKeyAndVisible()

        AnyLog.i("App 启动完成，SDKAppID=\(AnyConfig.sdkAppID)")
        return true
    }
}
