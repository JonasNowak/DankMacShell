import Foundation
import DMSCore

/// Fetches and caches live weather telemetry via Open-Meteo REST API.
@MainActor
public final class WeatherService: ObservableObject {
    public static let shared = WeatherService()

    @Published public private(set) var currentWeather: WeatherData = WeatherData()
    @Published public private(set) var locationName: String = "Berlin, Germany"
    @Published public private(set) var latitude: Double = 52.5200
    @Published public private(set) var longitude: Double = 13.4050
    @Published public private(set) var isFetching: Bool = false
    @Published public private(set) var lastFetchTime: Date?

    private static let knownCities: [String: (lat: Double, lon: Double, name: String)] = [
        "berlin": (52.5200, 13.4050, "Berlin, Germany"),
        "london": (51.5074, -0.1278, "London, United Kingdom"),
        "paris": (48.8566, 2.3522, "Paris, France"),
        "new york": (40.7128, -74.0060, "New York, United States"),
        "nyc": (40.7128, -74.0060, "New York, United States"),
        "tokyo": (35.6762, 139.6503, "Tokyo, Japan"),
        "san francisco": (37.7749, -122.4194, "San Francisco, United States"),
        "sf": (37.7749, -122.4194, "San Francisco, United States"),
        "los angeles": (34.0522, -118.2437, "Los Angeles, United States"),
        "la": (34.0522, -118.2437, "Los Angeles, United States"),
        "chicago": (41.8781, -87.6298, "Chicago, United States"),
        "toronto": (43.6532, -79.3832, "Toronto, Canada"),
        "vancouver": (49.2827, -123.1207, "Vancouver, Canada"),
        "sydney": (-33.8688, 151.2093, "Sydney, Australia"),
        "melbourne": (-37.8136, 144.9631, "Melbourne, Australia"),
        "amsterdam": (52.3676, 4.9041, "Amsterdam, Netherlands"),
        "madrid": (40.4168, -3.7038, "Madrid, Spain"),
        "rome": (41.9028, 12.4964, "Rome, Italy"),
        "vienna": (48.2082, 16.3738, "Vienna, Austria"),
        "zurich": (47.3769, 8.5417, "Zurich, Switzerland"),
        "warsaw": (52.2297, 21.0122, "Warsaw, Poland"),
        "prague": (50.0755, 14.4378, "Prague, Czechia"),
        "stockholm": (59.3293, 18.0686, "Stockholm, Sweden"),
        "oslo": (59.9139, 10.7522, "Oslo, Norway"),
        "copenhagen": (55.6761, 12.5683, "Copenhagen, Denmark"),
        "helsinki": (60.1699, 24.9384, "Helsinki, Finland"),
        "singapore": (1.3521, 103.8198, "Singapore"),
        "hong kong": (22.3193, 114.1694, "Hong Kong"),
        "seoul": (37.5665, 126.9780, "Seoul, South Korea"),
        "beijing": (39.9042, 116.4074, "Beijing, China"),
        "shanghai": (31.2304, 121.4737, "Shanghai, China"),
        "dubai": (25.2048, 55.2708, "Dubai, United Arab Emirates"),
        "mumbai": (19.0760, 72.8777, "Mumbai, India"),
        "sao paulo": (-23.5505, -46.6333, "São Paulo, Brazil"),
        "buenos aires": (-34.6037, -58.3816, "Buenos Aires, Argentina")
    ]

    private var activeGeocodeTask: Task<Void, Never>?
    private var activeWeatherTask: Task<Void, Never>?

    private init() {
        let savedLoc = ConfigStore.shared.config.weatherLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !savedLoc.isEmpty && savedLoc.lowercased() != "auto" {
            setManualLocation(savedLoc, fetch: true)
        } else {
            detectAutoLocationAndFetch()
        }
        // Refresh every 15 minutes
        Timer.scheduledTimer(withTimeInterval: 900.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchWeather()
            }
        }
    }

    /// Automatically detects user's location via IP geolocation APIs with zero-latency Berlin fallback.
    public func detectAutoLocationAndFetch() {
        activeGeocodeTask?.cancel()
        isFetching = true

        activeGeocodeTask = Task { [weak self] in
            defer {
                self?.isFetching = false
            }

            struct IPWhoIsResponse: Codable {
                let success: Bool?
                let city: String?
                let country: String?
                let latitude: Double?
                let longitude: Double?
            }

            struct IPApiResponse: Codable {
                let status: String?
                let city: String?
                let country: String?
                let lat: Double?
                let lon: Double?
            }

            var detectedLat: Double?
            var detectedLon: Double?
            var detectedName: String?

            // 1. Try ipwho.is (HTTPS)
            if let url = URL(string: "https://ipwho.is/"),
               let (data, res) = try? await URLSession.shared.data(from: url),
               let http = res as? HTTPURLResponse, http.statusCode == 200,
               let decoded = try? JSONDecoder().decode(IPWhoIsResponse.self, from: data),
               decoded.success == true,
               let lat = decoded.latitude, let lon = decoded.longitude, let city = decoded.city {
                detectedLat = lat
                detectedLon = lon
                detectedName = decoded.country != nil ? "\(city), \(decoded.country!)" : city
            }

            // 2. Fallback to ip-api.com (HTTP)
            if detectedLat == nil,
               let url = URL(string: "http://ip-api.com/json"),
               let (data, res) = try? await URLSession.shared.data(from: url),
               let http = res as? HTTPURLResponse, http.statusCode == 200,
               let decoded = try? JSONDecoder().decode(IPApiResponse.self, from: data),
               decoded.status?.lowercased() == "success",
               let lat = decoded.lat, let lon = decoded.lon, let city = decoded.city {
                detectedLat = lat
                detectedLon = lon
                detectedName = decoded.country != nil ? "\(city), \(decoded.country!)" : city
            }

            guard !Task.isCancelled else { return }

            if let lat = detectedLat, let lon = detectedLon, let name = detectedName {
                self?.latitude = lat
                self?.longitude = lon
                self?.locationName = name
            } else if self?.latitude == 0 && self?.longitude == 0 {
                // Safe default fallback
                self?.latitude = 52.5200
                self?.longitude = 13.4050
                self?.locationName = "Berlin, Germany"
            }
            self?.fetchWeather(force: true)
        }
    }

    /// Sets the manual location by coordinate string ("lat, lon") or city name query (e.g. "Tokyo", "Berlin", "San Francisco").
    public func setManualLocation(_ location: String, fetch: Bool = true) {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Update persistent config
        ConfigStore.shared.update { $0.weatherLocation = trimmed }

        // Case 0: Reset to Auto mode
        if trimmed.lowercased() == "auto" {
            detectAutoLocationAndFetch()
            return
        }

        // 1. Try coordinate format: "52.52, 13.405" or "52.52; 13.405" or "52.52 13.405"
        let separators = CharacterSet(charactersIn: ",; \t")
        let parts = trimmed.components(separatedBy: separators).filter { !$0.isEmpty }
        if parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]),
           lat >= -90.0, lat <= 90.0, lon >= -180.0, lon <= 180.0 {
            self.latitude = lat
            self.longitude = lon
            self.locationName = "Custom (\(String(format: "%.2f", lat)), \(String(format: "%.2f", lon)))"
            if fetch {
                fetchWeather(force: true)
            }
            return
        }

        // 2. Try known cities dictionary for zero-latency lookup
        let lower = trimmed.lowercased()
        if let match = Self.knownCities[lower] {
            self.latitude = match.lat
            self.longitude = match.lon
            self.locationName = match.name
            if fetch {
                fetchWeather(force: true)
            }
            return
        }

        // 3. Fallback to Open-Meteo Geocoding API
        if fetch {
            geocodeAndFetch(query: trimmed)
        } else {
            self.locationName = trimmed
        }
    }

    /// Explicitly sets numeric coordinates and optional location label.
    public func setLocation(latitude: Double, longitude: Double, name: String? = nil) {
        guard latitude >= -90.0, latitude <= 90.0, longitude >= -180.0, longitude <= 180.0 else { return }
        self.latitude = latitude
        self.longitude = longitude
        let label = name ?? "Custom (\(String(format: "%.2f", latitude)), \(String(format: "%.2f", longitude)))"
        self.locationName = label
        let configVal = name ?? "\(latitude),\(longitude)"
        ConfigStore.shared.update { $0.weatherLocation = configVal }
        fetchWeather(force: true)
    }

    private func geocodeAndFetch(query: String) {
        activeGeocodeTask?.cancel()

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else {
            return
        }

        self.isFetching = true

        activeGeocodeTask = Task.detached { [weak self] in
            struct GeocodingResponse: Codable {
                struct Result: Codable {
                    let name: String
                    let latitude: Double
                    let longitude: Double
                    let country: String?
                }
                let results: [Result]?
            }

            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let decoded = try? JSONDecoder().decode(GeocodingResponse.self, from: data) else {
                await MainActor.run {
                    self?.isFetching = false
                }
                return
            }

            guard !Task.isCancelled else { return }

            if let match = decoded.results?.first {
                await MainActor.run {
                    self?.latitude = match.latitude
                    self?.longitude = match.longitude
                    if let country = match.country, !country.isEmpty {
                        self?.locationName = "\(match.name), \(country)"
                    } else {
                        self?.locationName = match.name
                    }
                    self?.fetchWeather(force: true)
                }
            } else {
                await MainActor.run {
                    self?.isFetching = false
                    ToastCenter.shared.show(icon: "exclamationmark.triangle", message: "Location '\(query)' not found")
                }
            }
        }
    }

    public func fetchWeather(force: Bool = false) {
        if !force, let last = lastFetchTime, Date().timeIntervalSince(last) < 600 {
            return
        }

        activeWeatherTask?.cancel()

        let lat = self.latitude
        let lon = self.longitude
        let currentLocName = self.locationName
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"

        guard let url = URL(string: urlString) else { return }

        self.isFetching = true

        activeWeatherTask = Task { [weak self] in
            defer {
                self?.isFetching = false
            }

            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            struct OpenMeteoResponse: Codable {
                struct Current: Codable {
                    let temperature_2m: Double
                    let relative_humidity_2m: Int
                    let apparent_temperature: Double
                    let is_day: Int
                    let weather_code: Int
                    let wind_speed_10m: Double
                }
                let current: Current
            }

            guard let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
                return
            }

            guard !Task.isCancelled else { return }

            let weather = WeatherData(
                temperatureC: decoded.current.temperature_2m,
                apparentTemperatureC: decoded.current.apparent_temperature,
                weatherCode: decoded.current.weather_code,
                humidity: decoded.current.relative_humidity_2m,
                windSpeedKmh: decoded.current.wind_speed_10m,
                isDay: decoded.current.is_day == 1,
                locationName: currentLocName,
                updatedAt: Date()
            )

            self?.currentWeather = weather
            self?.lastFetchTime = Date()
        }
    }
}
