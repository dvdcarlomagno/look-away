import Foundation

struct AppConfig: Codable, Equatable {
    var workDurationMinutes: Int
    var breakDurationMinutes: Int
    var preBreakWarningMinutes: Int
    var idlePauseSeconds: Int?
    var launchAtLogin: Bool

    static let defaults = AppConfig(
        workDurationMinutes: 120,
        breakDurationMinutes: 15,
        preBreakWarningMinutes: 0,
        idlePauseSeconds: nil,
        launchAtLogin: true
    )

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
        if let idle = copy.idlePauseSeconds {
            copy.idlePauseSeconds = min(max(idle, 10), 3600)
        }
        return copy
    }
}
