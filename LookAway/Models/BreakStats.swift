import Foundation

struct BreakStats: Codable, Equatable {
    var consecutiveBreaks: Int = 0
    var pendingPenaltyMinutes: Int = 0
}

enum BreakStatsStore {
    private static var statsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/look-away/stats.json", isDirectory: false)
    }

    static func load() -> BreakStats {
        guard FileManager.default.fileExists(atPath: statsURL.path),
              let data = try? Data(contentsOf: statsURL),
              let stats = try? JSONDecoder().decode(BreakStats.self, from: data) else {
            return BreakStats()
        }
        return stats
    }

    static func save(_ stats: BreakStats) {
        let directory = statsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(stats) else { return }
        try? data.write(to: statsURL, options: .atomic)
    }
}
