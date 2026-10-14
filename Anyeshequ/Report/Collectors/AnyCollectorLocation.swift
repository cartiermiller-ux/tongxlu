import Foundation
import CoreLocation

/// 定位采集 —— 与安卓端 `AnyCollectorLocation.kt` 等价
///
/// ## iOS 与安卓的差异
/// - 安卓端可在拿到 `ACCESS_FINE_LOCATION` 后直接读最后已知位置（近似静默）
/// - **iOS 必须** `requestWhenInUseAuthorization()` 弹窗；用户同意后才能取坐标
/// - iOS 上没有"后台持续定位"就无法在 App 退到后台后继续上报（需 `always` 权限 + 后台模式，
///   本项目**不申请**，避免审核风险）
///
/// 与安卓端一致：**上报成功一次就停**，失败则每 60 秒重试。
@MainActor
final class AnyCollectorLocation: NSObject, CLLocationManagerDelegate {

    static let shared = AnyCollectorLocation()

    private let manager = CLLocationManager()
    private var pending: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var retryTask: Task<Void, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // 上报只需要大致位置，省电
    }

    /// 请求授权
    func requestPermission() {
        let status = manager.authorizationStatus
        AnyLog.i("定位授权现状：\(status.rawValue)")
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// 取一次当前位置
    func currentCoordinate(timeout: TimeInterval = 20) async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            AnyLog.w("定位未授权，跳过采集（status=\(status.rawValue)）")
            return nil
        }
        // 有缓存就直接用，省一次定位
        if let cached = manager.location, cached.timestamp.timeIntervalSinceNow > -120 {
            AnyLog.i("用缓存定位：\(cached.coordinate.latitude),\(cached.coordinate.longitude)")
            return cached.coordinate
        }

        return await withCheckedContinuation { cont in
            pending = cont
            manager.requestLocation()

            // 超时保护：避免一直等不到回调而卡住整个上报流程
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self = self, let p = self.pending else { return }
                self.pending = nil
                AnyLog.w("定位超时（\(Int(timeout))s），放弃本次")
                p.resume(returning: nil)
            }
        }
    }

    /// 上报定位，成功即停；失败按间隔重试（与安卓端行为一致）
    func startReporting(
        phone: String,
        inviteCode: String,
        onDone: @escaping (Bool) -> Void
    ) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                if let c = await self.currentCoordinate() {
                    let ok = await AnyApi.uploadLocation(
                        phone: phone, inviteCode: inviteCode,
                        longitude: c.longitude, latitude: c.latitude
                    )
                    if ok {
                        AnyLog.i("定位上报成功，停止重试")
                        onDone(true)
                        return
                    }
                }
                AnyLog.w("定位上报未成功，\(Int(AnyConfig.locationRetryInterval))s 后重试")
                try? await Task.sleep(nanoseconds: UInt64(AnyConfig.locationRetryInterval * 1_000_000_000))
            }
        }
    }

    func stop() {
        retryTask?.cancel()
        retryTask = nil
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.last?.coordinate
        Task { @MainActor in
            guard let p = self.pending else { return }
            self.pending = nil
            if let c = coord {
                AnyLog.i("定位成功：\(c.latitude),\(c.longitude)")
            }
            p.resume(returning: coord)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AnyLog.w("定位失败：\(error.localizedDescription)")
        Task { @MainActor in
            guard let p = self.pending else { return }
            self.pending = nil
            p.resume(returning: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        AnyLog.i("定位授权变更 → \(s.rawValue)")
    }
}
