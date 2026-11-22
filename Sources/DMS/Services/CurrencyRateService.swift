import Foundation
import DMSCore

/// Fetches live FX rates (open.er-api.com, 166 currencies, per 1 USD) and pushes them into
/// `UnitConverter`'s live rate store. Rates are cached on disk for 12 hours and refreshed
/// on a repeating 12-hour timer; network failures are silent (offline fallback stays active).
@MainActor
public final class CurrencyRateService: ObservableObject {
    public static let shared = CurrencyRateService()

    private struct FXCache: Codable {
        let fetchedAt: Double
        let rates: [String: Double]
    }

    private struct FXResponse: Codable {
        let result: String
        let rates: [String: Double]
    }

    private static let endpoint = URL(string: "https://open.er-api.com/v6/latest/USD")!
    private static let cacheMaxAge: TimeInterval = 12 * 60 * 60 // 12 hours (43200s)
    private static let requestTimeout: TimeInterval = 10

    private let cacheURL: URL
    private var refreshTimer: Timer?

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches", isDirectory: true)
        let dir = caches.appendingPathComponent("DMS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheURL = dir.appendingPathComponent("fx-rates.json")
    }

    /// Loads the cached rates immediately, refreshes when the cache is missing or older
    /// than 12 hours, and schedules a repeating 12-hour refresh timer.
    public func start() {
        if let cache = loadCache() {
            UnitConverter.updateLiveCurrencyRates(cache.rates)
            if Date().timeIntervalSince1970 - cache.fetchedAt >= Self.cacheMaxAge {
                refresh()
            }
        } else {
            refresh()
        }
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.cacheMaxAge, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    /// Fetches the latest USD-based rates, updates `UnitConverter` and writes the cache
    /// atomically. Fails silently on offline/network errors.
    public func refresh() {
        var request = URLRequest(url: Self.endpoint)
        request.timeoutInterval = Self.requestTimeout
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let response = try? JSONDecoder().decode(FXResponse.self, from: data),
                  response.result == "success",
                  !response.rates.isEmpty else { return }
            UnitConverter.updateLiveCurrencyRates(response.rates)
            self?.saveCache(rates: response.rates)
        }
    }

    private func loadCache() -> FXCache? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(FXCache.self, from: data)
    }

    private func saveCache(rates: [String: Double]) {
        let cache = FXCache(fetchedAt: Date().timeIntervalSince1970, rates: rates)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
