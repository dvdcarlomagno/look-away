import Foundation

struct AppConfig: Codable, Equatable {
    var workDurationMinutes: Int
    var breakDurationMinutes: Int
    var preBreakWarningMinutes: Int
    var skipPenaltyMinutes: Int
    var allowEmergencyExit: Bool
    var launchAtLogin: Bool

    static let defaults = AppConfig(
        workDurationMinutes: 120,
        breakDurationMinutes: 15,
        preBreakWarningMinutes: 0,
        skipPenaltyMinutes: 5,
        allowEmergencyExit: true,
        launchAtLogin: true
    )

    enum CodingKeys: String, CodingKey {
        case workDurationMinutes
        case breakDurationMinutes
        case preBreakWarningMinutes
        case skipPenaltyMinutes
        case allowEmergencyExit
        case launchAtLogin
    }

    init(
        workDurationMinutes: Int,
        breakDurationMinutes: Int,
        preBreakWarningMinutes: Int,
        skipPenaltyMinutes: Int,
        allowEmergencyExit: Bool,
        launchAtLogin: Bool
    ) {
        self.workDurationMinutes = workDurationMinutes
        self.breakDurationMinutes = breakDurationMinutes
        self.preBreakWarningMinutes = preBreakWarningMinutes
        self.skipPenaltyMinutes = skipPenaltyMinutes
        self.allowEmergencyExit = allowEmergencyExit
        self.launchAtLogin = launchAtLogin
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workDurationMinutes = try container.decode(Int.self, forKey: .workDurationMinutes)
        breakDurationMinutes = try container.decode(Int.self, forKey: .breakDurationMinutes)
        preBreakWarningMinutes = try container.decode(Int.self, forKey: .preBreakWarningMinutes)
        skipPenaltyMinutes = try container.decodeIfPresent(Int.self, forKey: .skipPenaltyMinutes) ?? Self.defaults.skipPenaltyMinutes
        allowEmergencyExit = try container.decodeIfPresent(Bool.self, forKey: .allowEmergencyExit) ?? Self.defaults.allowEmergencyExit
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? Self.defaults.launchAtLogin
    }

    var workDurationSeconds: TimeInterval {
        TimeInterval(workDurationMinutes * 60)
    }

    var breakDurationSeconds: TimeInterval {
        TimeInterval(breakDurationMinutes * 60)
    }

    var preBreakWarningSeconds: TimeInterval {
        TimeInterval(preBreakWarningMinutes * 60)
    }

    static func sanitized(_ config: AppConfig) -> AppConfig {
        var copy = config
        copy.workDurationMinutes = min(max(copy.workDurationMinutes, 1), 24 * 60)
        copy.breakDurationMinutes = min(max(copy.breakDurationMinutes, 1), 180)
        copy.preBreakWarningMinutes = min(max(copy.preBreakWarningMinutes, 0), 60)
        copy.skipPenaltyMinutes = min(max(copy.skipPenaltyMinutes, 0), 60)
        return copy
    }
}
