import Foundation

private struct AppSecrets: Codable {
    var unsplashAccessKey: String?
    /// Alias — same value as `unsplashAccessKey` (Unsplash calls this the Access Key / Client-ID).
    var unsplashClientId: String?
}

enum NatureBackgroundFailure: Equatable {
    case missingKey
    case unauthorized
    case requestFailed(statusCode: Int)
    case decodeFailed
    case imageDownloadFailed
}

@MainActor
final class SecretsManager: ObservableObject {
    static let shared = SecretsManager()

    @Published private(set) var unsplashAccessKey: String?

    private init() {
        reload()
    }

    func reload() {
        guard let secrets = loadSecretsFile() else {
            unsplashAccessKey = nil
            return
        }

        let candidates = [secrets.unsplashAccessKey, secrets.unsplashClientId]
        let key = candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        unsplashAccessKey = key
    }

    @discardableResult
    func saveUnsplashAccessKey(_ rawValue: String) -> Bool {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var secrets = loadSecretsFile() ?? AppSecrets(unsplashAccessKey: nil, unsplashClientId: nil)
        secrets.unsplashAccessKey = trimmed.isEmpty ? nil : trimmed

        do {
            try Self.ensureSecretsDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(secrets)
            try data.write(to: Self.secretsFileURL, options: .atomic)
            reload()
            return true
        } catch {
            NSLog("Look Away: failed to save secrets — \(error.localizedDescription)")
            return false
        }
    }

    static var secretsFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/look-away/secrets.json", isDirectory: false)
    }

    private static func ensureSecretsDirectoryExists() throws {
        let directory = secretsFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func loadSecretsFile() -> AppSecrets? {
        let secretsURL = Self.secretsFileURL
        guard
            FileManager.default.fileExists(atPath: secretsURL.path),
            let data = try? Data(contentsOf: secretsURL),
            let secrets = try? JSONDecoder().decode(AppSecrets.self, from: data)
        else {
            return nil
        }
        return secrets
    }
}
