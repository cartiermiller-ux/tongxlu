import ReplayKit
import TXLiteAVSDK_ReplayKitExt

/// ReplayKit 屏幕采集进程 —— iOS 跨应用屏幕共享的**必需组件**
///
/// ## 为什么必须单独建这个 Target
///
/// 安卓端的屏幕共享用 `MediaProjection`（系统级 API，应用自己申请权限即可）。
/// **iOS 被 Apple 强制拆成两个进程**：
/// - 主 App 进程：负责推流、在通话界面显示
/// - **本扩展进程**：系统在开始录屏时创建，负责接收系统采集到的屏幕画面
///
/// 没有这个 Target，iOS 上**无法共享整个屏幕**。唯一不需要扩展的是"应用内分享"
/// （`startScreenCaptureInApp`），但那只**能共享本 App 自己的画面**。
///
/// ## 依据
/// - 《开启屏幕分享 - iOS》https://cloud.tencent.com/document/product/647/45750
/// - 官方参考实现：`TUIKit_iOS/application/RTCubeReplayExtension/SampleHandler.m`
///   （本文件即按该官方实现改写，**API 用法与官方逐行一致，不是推测**）
///
/// ## App Group
/// 主 App 与扩展通过 App Group 跨进程传屏幕数据。`kAppGroupID` 必须与以下三处完全一致：
///   1. `Anyeshequ/Anyeshequ.entitlements`
///   2. `AnyeshequScreenShare/AnyeshequScreenShare.entitlements`
///   3. 主 App 的 `AnyScreenShare.appGroupID`
///
/// 并且在 developer.apple.com 要给**主 App 与扩展两个 App ID 都勾上**这个 App Group，
/// 然后**重新下载 Provisioning Profile** —— 否则屏幕共享起不来。
class SampleHandler: RPBroadcastSampleHandler {

    /// ⚠️ 三处必须一致（见类注释）
    private let kAppGroupID = "group.cn.anyeshequ.app"

    private lazy var replayKitExt: TXReplayKitExt = {
        let ext = TXReplayKitExt.sharedInstance()
        ext.setup(withAppGroup: kAppGroupID, delegate: self)
        return ext
    }()

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        NSLog("[ANY-EXT-I] broadcastStarted, appGroup=%@", kAppGroupID)
        // 官方写法：setup 一次即可，SDK 内部自建跨进程通道
        _ = replayKitExt
    }

    override func broadcastPaused() {
        NSLog("[ANY-EXT-I] broadcastPaused")
    }

    override func broadcastResumed() {
        NSLog("[ANY-EXT-I] broadcastResumed")
    }

    override func broadcastFinished() {
        NSLog("[ANY-EXT-I] broadcastFinished")
    }

    /// 官方实现对视频/音频**统一走一个方法**：
    /// ```objc
    /// [[TXReplayKitExt sharedInstance] sendSampleBuffer:sampleBuffer withType:sampleBufferType];
    /// ```
    /// 不要按 type 分开调不同的 send 方法 —— 官方没这些方法，分开写会编译不过。
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        objc_sync_enter(self)
        replayKitExt.sendSampleBuffer(sampleBuffer, with: sampleBufferType)
        objc_sync_exit(self)
    }
}

// MARK: - TXReplayKitExtDelegate

extension SampleHandler: TXReplayKitExtDelegate {

    /// 官方签名带 `reason` 参数（不是无参的 broadcastFinished）
    func broadcastFinished(_ broadcast: TXReplayKitExt, reason: TXReplayKitExtReason) {
        let tip: String
        switch reason {
        case .requestedByMain:
            tip = "屏幕共享已由主 App 结束"
        case .disconnected:
            tip = "主 App 已断开，共享结束"
        case .versionMismatch:
            tip = "ReplayKit 扩展与主 App 版本不匹配，请检查集成"
        @unknown default:
            tip = "屏幕共享已结束"
        }
        NSLog("[ANY-EXT-I] 主 App 要求结束共享：%@", tip)

        // 必须带 error 收尾，否则系统顶部的录屏指示条不会消失
        let err = NSError(domain: String(describing: type(of: self)),
                          code: 0,
                          userInfo: [NSLocalizedFailureReasonErrorKey: tip])
        finishBroadcastWithError(err)
    }
}
