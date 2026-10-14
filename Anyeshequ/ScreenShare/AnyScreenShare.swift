import Foundation
import UIKit
import ReplayKit
import AtomicXCore

/// 屏幕共享（主 App 侧）—— 对齐安卓端 `AnyScreenShare.kt`
///
/// ## 安卓与 iOS 的机制差异（重要）
///
/// | | 安卓（已实现并验证） | iOS（本文件） |
/// |---|---|---|
/// | 采集授权 | `MediaProjection` 系统弹窗，应用自己申请 | **系统级**，用户从控制中心长按录屏选 App |
/// | 采集进程 | 同进程 | **独立 Extension 进程**（`AnyeshequScreenShare`） |
/// | 推流 API | `TRTCCloud.startScreenCapture()` | `DeviceStore.startScreenShare(appGroup:)` |
/// | 一键唤起 | 无需（直接弹授权框） | 官方有 launcher，但**明确警告不被苹果推荐、可能失效** |
///
/// ## 为什么主 App 用 `DeviceStore` 而不是直接调 TRTC
/// `AtomicXCore`（TUIChatKit / TUICallKit 的公共依赖）已经封装好了跨进程对接：
/// ```swift
/// DeviceStore.shared.startScreenShare(appGroup: "group.cn.anyeshequ.app") { result in ... }
/// DeviceStore.shared.stopScreenShare()
/// ```
/// 用官方封装比我们手写 TRTC + 跨进程通知更稳，也更符合"用腾讯云官方的"这个要求。
///
/// ## ⚠️ 用户体验上的硬限制
/// iOS **无法像安卓那样"点一下按钮就直接开始共享"** —— 系统要求用户：
///   1. 从屏幕右上角下拉打开**控制中心**
///   2. **长按**录屏按钮
///   3. 在列表里选择「暗夜社区」
///   4. 点「开始直播」
///
/// 我们能做的是：调起 `RPSystemBroadcastPickerView`（系统选择器）帮用户少走两步，
/// 但**它是否真的弹出、以及弹出后的行为由系统决定**，官方也提示这个 launcher 有失效风险。
/// 所以 UI 上必须给出**文字引导**，不能只给一个按钮。
enum AnyScreenShare {

    /// ⚠️ 必须与两个 entitlements 文件里的 App Group 完全一致
    static let appGroupID = "group.cn.anyeshequ.app"

    /// 当前是否在共享中
    private(set) static var isSharing = false

    /// 状态变化回调（用于更新通话界面按钮文案）
    static var onStateChanged: ((Bool) -> Void)?

    // MARK: - 开始 / 停止

    /// 开始屏幕共享
    ///
    /// - Parameter completion: `true` = 已发起（**注意：不代表用户已在系统层点了「开始直播」**）
    static func start(completion: @escaping (Bool) -> Void) {
        AnyLog.i("请求开始屏幕共享，appGroup=\(appGroupID)")

        // 官方封装：App Group 必须传对，否则扩展进程与主 App 建不起通道
        DeviceStore.shared.startScreenShare(appGroup: appGroupID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    isSharing = true
                    AnyLog.i("屏幕共享已发起（等待用户在系统层确认开始直播）")
                    onStateChanged?(true)
                    completion(true)
                case .failure(let error):
                    isSharing = false
                    NSLog("[ANY-E] 屏幕共享发起失败：%d %@", error.code, error.message)
                    onStateChanged?(false)
                    completion(false)
                }
            }
        }
    }

    /// 停止屏幕共享
    static func stop() {
        guard isSharing else { return }
        DeviceStore.shared.stopScreenShare()
        isSharing = false
        AnyLog.i("屏幕共享已停止")
        onStateChanged?(false)
    }

    // MARK: - 一键唤起（尽力而为）

    /// 调起系统的「选择共享 App」选择器
    ///
    /// 说明：`RPSystemBroadcastPickerView` 是苹果提供的系统视图，
    /// 但它**只能由用户点击触发**，程序调用 `sendActions` 属于官方不推荐的做法
    /// （腾讯云官方文档也明确警告这个 launcher 靠遍历子视图点击、可能随系统更新失效）。
    ///
    /// 因此本方法**只作为辅助**：拿不到就返回 false，由 UI 显示文字引导让用户手动去控制中心。
    @discardableResult
    static func presentSystemBroadcastPicker(from view: UIView) -> Bool {
        let picker = RPSystemBroadcastPickerView(
            frame: CGRect(x: 0, y: 0, width: 44, height: 44)
        )
        picker.preferredExtension = Bundle.main.bundleIdentifier.map {
            // 扩展的 bundle id = 主 App 的 bundle id + ".ScreenShare"
            $0 + ".ScreenShare"
        }
        picker.showsMicrophoneButton = false

        // 找到系统选择器内部的按钮并触发（官方文档提到的做法，属于"尽力而为"）
        for sub in picker.subviews {
            if let button = sub as? UIButton {
                button.sendActions(for: .allTouchEvents)
                AnyLog.i("已尝试调起系统录屏选择器")
                return true
            }
        }
        AnyLog.w("未能调起系统录屏选择器，需要用户手动从控制中心开始")
        return false
    }

    /// 给用户看的操作引导（iOS 上必须显示这个，否则用户不知道怎么开始）
    static var manualGuideText: String {
        """
        在 iPhone 上开始共享屏幕：
        1. 从屏幕右上角向下滑，打开「控制中心」
        2. 长按 ⏺ 录屏按钮
        3. 在 App 列表中选择「暗夜社区」
        4. 点「开始直播」

        提示：共享期间 iPhone 顶部会显示红色状态条，点它可随时停止。
        """
    }
}
