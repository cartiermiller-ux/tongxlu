import Foundation

/// 本机会话 —— 与安卓端 `AnySession.kt` 等价
///
/// 只存三样：手机号、邀请码、app_user.id。
/// 安卓端用 MMKV，iOS 用 `UserDefaults`（数据量极小，没必要上 Keychain）。
///
/// 静默登录靠这里的手机号：已注册用户冷启动时直接用手机号换 UserSig，
/// **不需要再填一遍**（与安卓端体验一致）。
enum AnySession {

    private static let kPhone = "anye_phone"
    private static let kInvite = "anye_invite"
    private static let kUserId = "anye_user_id"
    private static let kRegistered = "anye_registered"
    private static let kFriendRuleInited = "anye_friend_rule_inited"
    private static let kBotCleaned = "anye_bot_cleaned"

    private static var d: UserDefaults { .standard }

    // MARK: - 手机号 / 邀请码

    static var phone: String {
        get { d.string(forKey: kPhone) ?? "" }
        set { d.set(newValue, forKey: kPhone) }
    }

    static var inviteCode: String {
        get { d.string(forKey: kInvite) ?? "" }
        set { d.set(newValue, forKey: kInvite) }
    }

    /// 服务端 `app_user.id`（相册上传需要）
    static var userId: Int64 {
        get { d.object(forKey: kUserId) as? Int64 ?? 0 }
        set { d.set(newValue, forKey: kUserId) }
    }

    /// 是否已在本机完成过注册
    static var isRegistered: Bool {
        get { d.bool(forKey: kRegistered) }
        set { d.set(newValue, forKey: kRegistered) }
    }

    /// 是否本机已初始化过「加我为好友」规则（幂等用，见 AnyLoginSetup）
    static var friendRuleInited: Bool {
        get { d.bool(forKey: kFriendRuleInited) }
        set { d.set(newValue, forKey: kFriendRuleInited) }
    }

    /// 是否已清理过 administrator 机器人会话
    static var botCleaned: Bool {
        get { d.bool(forKey: kBotCleaned) }
        set { d.set(newValue, forKey: kBotCleaned) }
    }

    static func clear() {
        [kPhone, kInvite, kUserId, kRegistered].forEach { d.removeObject(forKey: $0) }
    }

    static func save(phone: String, inviteCode: String, userId: Int64) {
        self.phone = phone
        self.inviteCode = inviteCode
        self.userId = userId
        self.isRegistered = true
    }
}
