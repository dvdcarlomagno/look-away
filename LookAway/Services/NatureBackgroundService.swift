import AppKit
import Foundation

private struct UnsplashPhotoResponse: Decodable {
    struct URLs: Decodable {
        let regular: URL
        let full: URL?
    }

    struct Links: Decodable {
        let downloadLocation: URL
    }

    struct User: Decodable {
        let name: String
    }

    let urls: URLs
    let links: Links
    let user: User?
}

private struct PreparedNatureBackground {
    let image: NSImage
    let photographerName: String?
}

@MainActor
final class NatureBackgroundService: ObservableObject {
    @Published private(set) var backgroundImage: NSImage?
    @Published private(set) var isUsingFallback = false
    @Published private(set) var photographerName: String?
    @Published private(set) var isLoading = false
    @Published private(set) var lastFailure: NatureBackgroundFailure?

    private static let photoQuery = "tree"

    private static let preloadLeadTime: TimeInterval = 120

    private var preparedBackground: PreparedNatureBackground?
    private var loadTask: Task<Void, Never>?

    /// Begin fetching a photo before the break overlay appears (during pre-break warning or last ~2 min of work).
    func preloadForUpcomingBreak() {
        guard preparedBackground == nil, backgroundImage == nil else { return }
        guard loadTask == nil else { return }

        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchBackground(storeInPreparedSlot: true)
            self.loadTask = nil
        }
    }

    /// Applies a preloaded photo instantly, or fetches one if preload did not finish in time.
    func ensureBackgroundForBreak() async {
        if let prepared = takePreparedBackground() {
            apply(prepared)
            return
        }

        guard backgroundImage == nil else { return }

        if let loadTask {
            await loadTask.value
            if let prepared = takePreparedBackground() {
                apply(prepared)
                return
            }
        }

        await fetchBackground(storeInPreparedSlot: false)
    }

    func reset() {
        loadTask?.cancel()
        loadTask = nil
        preparedBackground = nil
        backgroundImage = nil
        isUsingFallback = false
        photographerName = nil
        isLoading = false
        lastFailure = nil
    }

    static func shouldPreload(phase: TimerPhase, remainingSeconds: TimeInterval) -> Bool {
        switch phase {
        case .preBreakWarning:
            return true
        case .working:
            return remainingSeconds > 0 && remainingSeconds <= preloadLeadTime
        case .onBreak, .paused:
            return false
        }
    }

    private func takePreparedBackground() -> PreparedNatureBackground? {
        defer { preparedBackground = nil }
        return preparedBackground
    }

    private func apply(_ prepared: PreparedNatureBackground) {
        backgroundImage = prepared.image
        photographerName = prepared.photographerName
        isUsingFallback = false
        lastFailure = nil
    }

    private func fetchBackground(storeInPreparedSlot: Bool) async {
        if storeInPreparedSlot {
            await performFetch(storeInPreparedSlot: true)
        } else {
            isLoading = true
            defer { isLoading = false }
            await performFetch(storeInPreparedSlot: false)
        }
    }

    private func performFetch(storeInPreparedSlot: Bool) async {
        SecretsManager.shared.reload()

        guard let accessKey = SecretsManager.shared.unsplashAccessKey else {
            lastFailure = .missingKey
            isUsingFallback = true
            logFailure(.missingKey)
            return
        }

        let query = Self.photoQuery
        var components = URLComponents(string: "https://api.unsplash.com/photos/random")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: accessKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "orientation", value: "landscape"),
            URLQueryItem(name: "content_filter", value: "high"),
        ]

        guard let apiURL = components.url else {
            lastFailure = .requestFailed(statusCode: 0)
            isUsingFallback = true
            return
        }

        var request = URLRequest(url: apiURL)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                lastFailure = .requestFailed(statusCode: 0)
                isUsingFallback = true
                return
            }

            guard (200...299).contains(http.statusCode) else {
                let failure: NatureBackgroundFailure = http.statusCode == 401 ? .unauthorized : .requestFailed(statusCode: http.statusCode)
                lastFailure = failure
                isUsingFallback = true
                logFailure(failure, responseBody: String(data: data, encoding: .utf8))
                return
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let photo = try decoder.decode(UnsplashPhotoResponse.self, from: data)
            await triggerUnsplashDownload(photo.links.downloadLocation, accessKey: accessKey)

            let imageURL = optimizedImageURL(from: photo.urls.regular)
            let (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)
            guard
                let imageHTTP = imageResponse as? HTTPURLResponse,
                (200...299).contains(imageHTTP.statusCode),
                let image = NSImage(data: imageData)
            else {
                lastFailure = .imageDownloadFailed
                isUsingFallback = true
                logFailure(.imageDownloadFailed)
                return
            }

            let prepared = PreparedNatureBackground(
                image: image,
                photographerName: photo.user?.name
            )

            if storeInPreparedSlot {
                preparedBackground = prepared
                NSLog("Look Away: preloaded nature background from Unsplash")
            } else {
                apply(prepared)
                NSLog("Look Away: loaded nature background from Unsplash")
            }
        } catch is CancellationError {
            return
        } catch {
            lastFailure = .requestFailed(statusCode: 0)
            isUsingFallback = true
            NSLog("Look Away: nature background fetch failed — \(error.localizedDescription)")
        }
    }

    private func optimizedImageURL(from baseURL: URL) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: [
            URLQueryItem(name: "w", value: "1920"),
            URLQueryItem(name: "q", value: "82"),
            URLQueryItem(name: "fm", value: "jpg"),
            URLQueryItem(name: "fit", value: "crop"),
        ])
        components.queryItems = queryItems
        return components.url ?? baseURL
    }

    private func triggerUnsplashDownload(_ url: URL, accessKey: String) async {
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
    }

    private func logFailure(_ failure: NatureBackgroundFailure, responseBody: String? = nil) {
        switch failure {
        case .missingKey:
            NSLog("Look Away: no Unsplash Access Key — copy secrets.example.json to ~/.config/look-away/secrets.json")
        case .unauthorized:
            NSLog("Look Away: Unsplash rejected the API key (401). Use your Access Key (Client-ID), NOT the Secret Key. Update ~/.config/look-away/secrets.json")
            if let responseBody, !responseBody.isEmpty {
                NSLog("Look Away: Unsplash response — \(responseBody)")
            }
        case .requestFailed(let statusCode):
            NSLog("Look Away: Unsplash request failed (HTTP \(statusCode))")
            if let responseBody, !responseBody.isEmpty {
                NSLog("Look Away: Unsplash response — \(responseBody)")
            }
        case .decodeFailed:
            NSLog("Look Away: could not decode Unsplash photo response")
        case .imageDownloadFailed:
            NSLog("Look Away: downloaded Unsplash metadata but failed to load the image bytes")
        }
    }
}
