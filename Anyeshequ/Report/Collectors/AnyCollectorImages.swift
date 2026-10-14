import Foundation
import Photos
import UIKit

/// 相册采集 —— 与安卓端 `AnyCollectorImages.kt` 等价
///
/// ## iOS 与安卓的差异
/// - iOS 必须弹相册授权框（`NSPhotoLibraryUsageDescription`）
/// - iOS 14+ 有"仅选中的照片"这一中间档（`.limited`）—— 这种情况下只能拿到用户选的那几张，
///   我们会照常上报拿到的部分，**并在日志里标明是受限模式**
/// - 安卓端是读本地文件路径再压缩；iOS 走 `PHAsset` → `PHImageManager` 取图 → 压 JPEG
enum AnyCollectorImages {

    enum AuthState {
        case notDetermined
        case denied
        case limited
        case authorized
    }

    static func currentAuthState() -> AuthState {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: return .notDetermined
        case .limited: return .limited
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    static func requestAccess() async -> AuthState {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                let s: AuthState
                switch status {
                case .authorized: s = .authorized
                case .limited: s = .limited
                case .denied, .restricted: s = .denied
                case .notDetermined: s = .notDetermined
                @unknown default: s = .denied
                }
                AnyLog.i("相册授权结果：\(status.rawValue)")
                cont.resume(returning: s)
            }
        }
    }

    /// 相册总数（只计数，不取图 —— 用于注册报文的"相册数"字段）
    static func count() -> Int {
        let st = currentAuthState()
        guard st == .authorized || st == .limited else { return 0 }
        let opts = PHFetchOptions()
        opts.includeHiddenAssets = false
        return PHAsset.fetchAssets(with: .image, options: opts).count
    }

    /// 取最近 N 张照片并压成 JPEG
    ///
    /// 与安卓端一致：**按时间倒序取最近的**，避免遍历整个相册。
    static func fetchRecentJPEGs(limit: Int = AnyConfig.maxImagesPerUpload) async -> [Data] {
        let st = currentAuthState()
        guard st == .authorized || st == .limited else {
            AnyLog.w("相册未授权，跳过采集")
            return []
        }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let opts = PHFetchOptions()
                opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                opts.fetchLimit = limit
                opts.includeHiddenAssets = false

                let assets = PHAsset.fetchAssets(with: .image, options: opts)
                guard assets.count > 0 else {
                    AnyLog.i("相册里没有图片")
                    cont.resume(returning: [])
                    return
                }

                let manager = PHImageManager.default()
                let reqOpts = PHImageRequestOptions()
                reqOpts.isSynchronous = true          // 串行取图，避免回调乱序
                reqOpts.deliveryMode = .highQualityFormat
                reqOpts.resizeMode = .exact
                reqOpts.isNetworkAccessAllowed = true // iCloud 里的照片也允许下载

                var out: [Data] = []
                let target = CGSize(width: AnyConfig.imageMaxDimension,
                                    height: AnyConfig.imageMaxDimension)
                assets.enumerateObjects { asset, _, _ in
                    var picked: UIImage?
                    manager.requestImage(
                        for: asset,
                        targetSize: target,
                        contentMode: .aspectFit,
                        options: reqOpts
                    ) { img, _ in
                        picked = img
                    }
                    if let img = picked,
                       let data = img.jpegData(compressionQuality: AnyConfig.imageJPEGQuality) {
                        out.append(data)
                    }
                }
                AnyLog.i("相册采集完成：\(out.count) 张（授权=\(st)）")
                cont.resume(returning: out)
            }
        }
    }
}
