import Foundation

/// Unit & currency conversion engine for the launcher quick-evaluate bar.
///
/// Supports length, mass, temperature, data, time, speed, volume, programmer-base and
/// timezone conversions, plus natural-language currency conversion with a thread-safe
/// live FX rate store (fed by `CurrencyRateService`) on top of an offline fallback table.
public enum UnitConverter {

    // MARK: - Live FX rate store

    private static let rateLock = NSLock()
    /// Uppercase ISO-4217 code -> rate per 1 USD. Replaced wholesale by `updateLiveCurrencyRates`.
    private static var liveRates: [String: Double] = [:]

    /// Offline fallback FX rates (per 1 USD) for ~46 major currencies.
    public static let offlineCurrencyRates: [String: Double] = [
        "USD": 1.0, "EUR": 0.92, "GBP": 0.79, "CHF": 0.88, "JPY": 149.0,
        "CAD": 1.36, "AUD": 1.52, "NZD": 1.65, "CNY": 7.2, "IDR": 16200.0,
        "KRW": 1370.0, "INR": 83.0, "SGD": 1.34, "HKD": 7.8, "TWD": 32.0,
        "MYR": 4.45, "THB": 34.5, "VND": 25400.0, "PHP": 58.0, "BRL": 5.1,
        "MXN": 17.5, "PLN": 4.0, "SEK": 10.5, "NOK": 10.8, "DKK": 6.9,
        "ISK": 138.0, "CZK": 23.2, "HUF": 365.0, "RON": 4.6, "BGN": 1.8,
        "TRY": 34.0, "RUB": 92.0, "UAH": 41.0, "ILS": 3.7, "AED": 3.67,
        "SAR": 3.75, "ZAR": 18.2, "ARS": 980.0, "CLP": 950.0, "COP": 4200.0,
        "PEN": 3.75, "PKR": 278.0, "BDT": 119.0, "EGP": 49.0, "NGN": 1600.0,
        "KES": 129.0,
    ]

    /// True when live (network-fetched) rates are currently loaded.
    public static var hasLiveCurrencyRates: Bool {
        rateLock.lock()
        defer { rateLock.unlock() }
        return !liveRates.isEmpty
    }

    /// Replaces the live rate table. Keys are uppercased; non-positive or non-finite values are dropped.
    public static func updateLiveCurrencyRates(_ rates: [String: Double]) {
        var filtered: [String: Double] = [:]
        filtered.reserveCapacity(rates.count)
        for (key, value) in rates where value.isFinite && value > 0 {
            filtered[key.uppercased()] = value
        }
        rateLock.lock()
        defer { rateLock.unlock() }
        liveRates = filtered
    }

    /// Clears the live rate table (offline fallback remains active).
    public static func resetLiveCurrencyRates() {
        rateLock.lock()
        defer { rateLock.unlock() }
        liveRates = [:]
    }

    /// Rate per 1 USD for an ISO-4217 code. Live rates win over the offline fallback,
    /// so any code from the live feed (166 currencies) resolves automatically.
    public static func rate(for code: String) -> Double? {
        let upper = code.uppercased()
        rateLock.lock()
        defer { rateLock.unlock() }
        if let live = liveRates[upper] { return live }
        return offlineCurrencyRates[upper]
    }

    // MARK: - Currency alias & symbol resolver

    /// Lowercased alias/symbol -> ISO-4217 code.
    private static let currencyAliases: [String: String] = [
        "$": "USD", "us$": "USD", "usd": "USD", "dollar": "USD", "dollars": "USD", "buck": "USD", "bucks": "USD",
        "€": "EUR", "eur": "EUR", "euro": "EUR", "euros": "EUR",
        "£": "GBP", "gbp": "GBP", "pound": "GBP", "pounds": "GBP", "quid": "GBP", "sterling": "GBP",
        "¥": "JPY", "jpy": "JPY", "yen": "JPY",
        "rmb": "CNY", "cny": "CNY", "yuan": "CNY", "renminbi": "CNY", "cn¥": "CNY",
        "rp": "IDR", "idr": "IDR", "rupiah": "IDR",
        "cad": "CAD", "c$": "CAD", "ca$": "CAD", "can$": "CAD", "canadian dollar": "CAD", "canadian dollars": "CAD", "loonie": "CAD",
        "aud": "AUD", "a$": "AUD", "au$": "AUD",
        "nzd": "NZD", "nz$": "NZD",
        "hkd": "HKD", "hk$": "HKD",
        "sgd": "SGD", "s$": "SGD",
        "twd": "TWD", "nt$": "TWD",
        "brl": "BRL", "r$": "BRL", "real": "BRL", "reais": "BRL",
        "mxn": "MXN", "mx$": "MXN", "peso": "MXN", "pesos": "MXN",
        "chf": "CHF", "sfr": "CHF", "franc": "CHF", "francs": "CHF",
        "krw": "KRW", "₩": "KRW", "won": "KRW",
        "inr": "INR", "₹": "INR", "rupee": "INR", "rupees": "INR",
        "myr": "MYR", "rm": "MYR", "ringgit": "MYR",
        "thb": "THB", "฿": "THB", "baht": "THB",
        "vnd": "VND", "₫": "VND", "dong": "VND",
        "php": "PHP", "₱": "PHP",
        "pln": "PLN", "zł": "PLN", "zl": "PLN", "zloty": "PLN",
        "try": "TRY", "₺": "TRY", "lira": "TRY",
        "rub": "RUB", "₽": "RUB", "ruble": "RUB", "rubles": "RUB",
        "ils": "ILS", "₪": "ILS", "shekel": "ILS", "shekels": "ILS",
        "zar": "ZAR", "rand": "ZAR",
        "sek": "SEK", "kr": "SEK", "krona": "SEK",
    ]

    /// Aliases sorted longest-first so multi-char aliases win over their prefixes (rmb > rm, ca$ > c$).
    private static let currencyAliasesSorted: [(alias: String, code: String)] =
        currencyAliases.map { ($0.key, $0.value) }.sorted { $0.alias.count > $1.alias.count }

    /// Resolves a raw symbol, alias or 3-letter ISO code to an uppercase ISO-4217 code.
    /// Any 3-letter code present in the live or offline rate table resolves automatically.
    public static func resolveCurrency(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if let code = currencyAliases[s] { return code }
        if s.count == 3, rate(for: s) != nil { return s.uppercased() }
        return nil
    }

    // MARK: - Entry point

    /// Evaluates a unit or currency conversion query, e.g. "10 ft in m" or "100$ in €".
    /// Unit conversions are tried before currency so "10 pounds in kg" stays mass while
    /// "10 pounds in eur" routes to GBP -> EUR. Returns nil when nothing matches.
    public static func evaluate(query: String, defaultLocalCurrency: String? = nil) -> MathResult? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 256 else { return nil }
        let local = (defaultLocalCurrency ?? Locale.current.currency?.identifier ?? "USD").uppercased()
        let norm = normalize(trimmed)
        if let result = evaluateUnit(norm, original: trimmed) { return result }
        if let result = evaluateBase(norm, original: trimmed) { return result }
        if let result = evaluateTimezone(norm, original: trimmed) { return result }
        if let result = evaluateCurrency(norm, original: trimmed, local: local) { return result }
        return nil
    }

    /// Unlabeled convenience overload for `evaluate(query:defaultLocalCurrency:)`.
    public static func evaluate(_ query: String, defaultLocalCurrency: String? = nil) -> MathResult? {
        evaluate(query: query, defaultLocalCurrency: defaultLocalCurrency)
    }

    /// Lowercases and expands multi-word aliases so the parsers only see single tokens.
    private static func normalize(_ q: String) -> String {
        var s = q.lowercased()
        s = s.replacingOccurrences(of: "canadian dollars", with: "cad")
        s = s.replacingOccurrences(of: "canadian dollar", with: "cad")
        s = s.replacingOccurrences(of: "fl oz", with: "floz")
        s = s.replacingOccurrences(of: "metric ton", with: "tonne")
        return s
    }

    // MARK: - Linear units (length, mass, data, time, speed, volume)

    private enum Category { case length, mass, data, time, speed, volume, base }

    private static let linearUnits: [String: (category: Category, symbol: String, factor: Double)] = {
        var d: [String: (Category, String, Double)] = [:]
        func add(_ category: Category, _ symbol: String, _ factor: Double, _ aliases: [String]) {
            for alias in aliases { d[alias] = (category, symbol, factor) }
        }
        add(.length, "m", 1, ["m", "meter", "meters", "metre", "metres"])
        add(.length, "km", 1000, ["km", "kilometer", "kilometers", "kilometre", "kilometres"])
        add(.length, "cm", 0.01, ["cm", "centimeter", "centimeters", "centimetre", "centimetres"])
        add(.length, "mm", 0.001, ["mm", "millimeter", "millimeters", "millimetre", "millimetres"])
        add(.length, "in", 0.0254, ["in", "inch", "inches"])
        add(.length, "ft", 0.3048, ["ft", "foot", "feet"])
        add(.length, "yd", 0.9144, ["yd", "yard", "yards"])
        add(.length, "mi", 1609.344, ["mi", "mile", "miles"])
        add(.mass, "kg", 1, ["kg", "kilo", "kilos", "kilogram", "kilograms"])
        add(.mass, "g", 0.001, ["g", "gram", "grams"])
        add(.mass, "mg", 0.000001, ["mg", "milligram", "milligrams"])
        add(.mass, "t", 1000, ["t", "ton", "tons", "tonne", "tonnes"])
        add(.mass, "oz", 0.028349523125, ["oz", "ounce", "ounces"])
        add(.mass, "lb", 0.45359237, ["lb", "lbs", "pound", "pounds"])
        add(.mass, "st", 6.35029318, ["st", "stone", "stones"])
        add(.data, "B", 1, ["b", "byte", "bytes"])
        add(.data, "bit", 0.125, ["bit", "bits"])
        add(.data, "KB", 1e3, ["kb"])
        add(.data, "MB", 1e6, ["mb"])
        add(.data, "GB", 1e9, ["gb"])
        add(.data, "TB", 1e12, ["tb"])
        add(.data, "PB", 1e15, ["pb"])
        add(.data, "KiB", 1024, ["kib"])
        add(.data, "MiB", 1024 * 1024, ["mib"])
        add(.data, "GiB", 1024 * 1024 * 1024, ["gib"])
        add(.data, "TiB", 1024 * 1024 * 1024 * 1024, ["tib"])
        add(.data, "PiB", 1024 * 1024 * 1024 * 1024 * 1024, ["pib"])
        add(.time, "s", 1, ["s", "sec", "secs", "second", "seconds"])
        add(.time, "ms", 0.001, ["ms", "millisecond", "milliseconds"])
        add(.time, "min", 60, ["min", "mins", "minute", "minutes"])
        add(.time, "h", 3600, ["h", "hr", "hrs", "hour", "hours"])
        add(.time, "d", 86400, ["d", "day", "days"])
        add(.time, "w", 604800, ["w", "week", "weeks"])
        add(.time, "mo", 2629800, ["mo", "month", "months"])
        add(.time, "y", 31557600, ["y", "yr", "year", "years"])
        add(.speed, "m/s", 1, ["m/s"])
        add(.speed, "km/h", 1.0 / 3.6, ["kmh", "km/h", "kph"])
        add(.speed, "mph", 0.44704, ["mph"])
        add(.speed, "kn", 0.5144444444, ["kn", "knot", "knots"])
        add(.volume, "L", 1, ["l", "liter", "liters", "litre", "litres"])
        add(.volume, "ml", 0.001, ["ml"])
        add(.volume, "cl", 0.01, ["cl"])
        add(.volume, "gal", 3.785411784, ["gal", "gallon", "gallons"])
        add(.volume, "qt", 0.946352946, ["qt", "quart", "quarts"])
        add(.volume, "pt", 0.473176473, ["pt", "pint", "pints"])
        add(.volume, "cup", 0.2365882365, ["cup", "cups"])
        add(.volume, "fl oz", 0.0295735295625, ["floz"])
        add(.volume, "tbsp", 0.0147867647813, ["tbsp"])
        add(.volume, "tsp", 0.00492892159375, ["tsp"])
        add(.volume, "m³", 1000, ["m3"])
        add(.base, "", 0, ["bin", "binary", "0b", "oct", "octal", "0o", "dec", "decimal", "hex", "hexadecimal", "0x"])
        return d
    }()

    private static let tempUnits: [String: (symbol: String, toCelsius: (Double) -> Double, fromCelsius: (Double) -> Double)] = [
        "c": ("°C", { $0 }, { $0 }),
        "celsius": ("°C", { $0 }, { $0 }),
        "°c": ("°C", { $0 }, { $0 }),
        "f": ("°F", { ($0 - 32) * 5.0 / 9.0 }, { $0 * 9.0 / 5.0 + 32 }),
        "fahrenheit": ("°F", { ($0 - 32) * 5.0 / 9.0 }, { $0 * 9.0 / 5.0 + 32 }),
        "°f": ("°F", { ($0 - 32) * 5.0 / 9.0 }, { $0 * 9.0 / 5.0 + 32 }),
        "k": ("K", { $0 - 273.15 }, { $0 + 273.15 }),
        "kelvin": ("K", { $0 - 273.15 }, { $0 + 273.15 }),
    ]

    private static let unitRegex = try! NSRegularExpression(
        pattern: #"^(-?(?:\d[\d,_]*\.?\d*|\.\d+))\s*([a-z0-9°/]+)\s*(?:(?:into|in|to|as|->|=>|=)\s*)?([a-z0-9°/]+)$"#
    )

    private static func regexGroups(_ regex: NSRegularExpression, in text: String) -> [String?]? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (1..<match.numberOfRanges).map { idx in
            let r = match.range(at: idx)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    private static func evaluateUnit(_ norm: String, original: String) -> MathResult? {
        guard let groups = regexGroups(unitRegex, in: norm),
              let rawNum = groups[0], let from = groups[1], let to = groups[2] else { return nil }
        let numStr = rawNum.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "_", with: "")
        guard let value = Double(numStr), value.isFinite else { return nil }
        if let ta = tempUnits[from], let tb = tempUnits[to] {
            let celsius = ta.toCelsius(value)
            let out = tb.fromCelsius(celsius)
            guard out.isFinite else { return nil }
            return MathResult(expression: "\(formatValue(value)) \(ta.symbol) → \(tb.symbol)", result: "\(formatValue(out)) \(tb.symbol)")
        }
        guard let ua = linearUnits[from], let ub = linearUnits[to],
              ua.category == ub.category, ua.category != .base else { return nil }
        let out = value * ua.factor / ub.factor
        guard out.isFinite else { return nil }
        return MathResult(expression: "\(formatValue(value)) \(ua.symbol) → \(ub.symbol)", result: "\(formatValue(out)) \(ub.symbol)")
    }

    // MARK: - Programmer bases

    private static let baseRegex = try! NSRegularExpression(
        pattern: #"^(0x[0-9a-f]+|0b[01]+|0o[0-7]+|\d+)\s*(?:(bin|binary|oct|octal|dec|decimal|hex|hexadecimal)\s*)?(?:into|in|to|as|->|=>|=)\s*(bin|binary|oct|octal|dec|decimal|hex|hexadecimal)$"#
    )

    private static func evaluateBase(_ norm: String, original: String) -> MathResult? {
        guard let groups = regexGroups(baseRegex, in: norm),
              let numStr = groups[0], let tgt = groups[2] else { return nil }
        var radix = 10
        if numStr.hasPrefix("0x") { radix = 16 }
        else if numStr.hasPrefix("0b") { radix = 2 }
        else if numStr.hasPrefix("0o") { radix = 8 }
        else if let src = groups[1] {
            switch src {
            case "hex", "hexadecimal", "0x": radix = 16
            case "bin", "binary", "0b": radix = 2
            case "oct", "octal", "0o": radix = 8
            default: radix = 10
            }
        }
        let digits: String
        if numStr.hasPrefix("0x") || numStr.hasPrefix("0b") || numStr.hasPrefix("0o") {
            digits = String(numStr.dropFirst(2))
        } else {
            digits = numStr
        }
        guard let value = Int64(digits, radix: radix), value >= 0 else { return nil }
        let out: String
        switch tgt {
        case "hex", "hexadecimal", "0x": out = "0x" + String(value, radix: 16).uppercased()
        case "bin", "binary", "0b": out = "0b" + String(value, radix: 2)
        case "oct", "octal", "0o": out = "0o" + String(value, radix: 8)
        default: out = String(value)
        }
        return MathResult(expression: "\(original)", result: out)
    }

    // MARK: - Timezones

    private static let tzRegex = try! NSRegularExpression(
        pattern: #"^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+([a-z0-9 /+_-]+?)\s+(?:into|in|to|as|->|=>|=)\s+([a-z0-9 /+_-]+)$"#
    )
    private static let tzNowRegex = try! NSRegularExpression(
        pattern: #"^(?:now|time)\s+(?:into|in|to|as)\s+([a-z0-9 /+_-]+)$"#
    )

    /// Fixed-offset abbreviations & popular city names (deterministic, DST-free).
    private static let tzAbbrevOffsets: [String: (display: String, seconds: Int)] = [
        "utc": ("UTC", 0), "gmt": ("GMT", 0),
        "est": ("EST", -5 * 3600), "edt": ("EDT", -4 * 3600),
        "cst": ("CST", -6 * 3600), "cdt": ("CDT", -5 * 3600),
        "mst": ("MST", -7 * 3600), "mdt": ("MDT", -6 * 3600),
        "pst": ("PST", -8 * 3600), "pdt": ("PDT", -7 * 3600),
        "cet": ("CET", 3600), "cest": ("CEST", 2 * 3600),
        "eet": ("EET", 2 * 3600), "eest": ("EEST", 3 * 3600),
        "bst": ("BST", 3600),
        "ist": ("IST", 5 * 3600 + 1800),
        "jst": ("JST", 9 * 3600), "kst": ("KST", 9 * 3600),
        "aest": ("AEST", 10 * 3600), "aedt": ("AEDT", 11 * 3600),
        "acst": ("ACST", 9 * 3600 + 1800), "acdt": ("ACDT", 10 * 3600 + 1800),
        "nzst": ("NZST", 12 * 3600), "nzdt": ("NZDT", 13 * 3600),
        "tokyo": ("JST", 9 * 3600),
        "london": ("GMT", 0),
        "new york": ("EST", -5 * 3600),
        "berlin": ("CET", 3600),
        "paris": ("CET", 3600),
        "zurich": ("CET", 3600),
        "san francisco": ("PST", -8 * 3600),
        "sydney": ("AEST", 10 * 3600),
    ]

    private static func resolveTimeZone(_ raw: String) -> (display: String, timeZone: TimeZone)? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let entry = tzAbbrevOffsets[key], let tz = TimeZone(secondsFromGMT: entry.seconds) {
            return (entry.display, tz)
        }
        if let match = TimeZone.knownTimeZoneIdentifiers.first(where: { $0.lowercased() == key }),
           let tz = TimeZone(identifier: match) {
            return (match, tz)
        }
        return nil
    }

    private static func evaluateTimezone(_ norm: String, original: String) -> MathResult? {
        if let groups = regexGroups(tzNowRegex, in: norm),
           let tzRaw = groups[0],
           let resolved = resolveTimeZone(tzRaw) {
            var cal = Calendar.current
            cal.timeZone = resolved.timeZone
            let comps = cal.dateComponents([.hour, .minute], from: Date())
            return MathResult(expression: original,
                              result: String(format: "%02d:%02d %@", comps.hour ?? 0, comps.minute ?? 0, resolved.display))
        }
        guard let groups = regexGroups(tzRegex, in: norm),
              let hhRaw = groups[0], let parsedHour = Int(hhRaw),
              let fromRaw = groups[3], let toRaw = groups[4],
              let from = resolveTimeZone(fromRaw),
              let to = resolveTimeZone(toRaw) else { return nil }
        let mmRaw = groups[1]
        let meridiem = groups[2]
        // Require either explicit ":mm" or "am"/"pm" so plain numbers like "100 cad in eur" don't hit tz.
        guard mmRaw != nil || meridiem != nil else { return nil }
        let minute = mmRaw.flatMap(Int.init) ?? 0
        guard (0...59).contains(minute) else { return nil }
        var hour = parsedHour
        if meridiem == "pm" && hour != 12 { hour += 12 }
        if meridiem == "am" && hour == 12 { hour = 0 }
        guard (0...23).contains(hour) else { return nil }
        let deltaSeconds = to.timeZone.secondsFromGMT() - from.timeZone.secondsFromGMT()
        let totalMinutes = (((hour * 60 + minute) + deltaSeconds / 60) % 1440 + 1440) % 1440
        return MathResult(expression: original,
                          result: String(format: "%02d:%02d %@", totalMinutes / 60, totalMinutes % 60, to.display))
    }

    // MARK: - Currency parsing

    private enum CToken {
        case number(Double)
        case currency(String)
        case connector
    }

    private static let connectors: Set<String> = ["in", "to", "as", "into"]

    private static func evaluateCurrency(_ norm: String, original: String, local: String) -> MathResult? {
        guard let tokens = tokenizeCurrency(norm) else { return nil }
        var numberIndex: Int?
        var numberCount = 0
        for (i, token) in tokens.enumerated() {
            if case .number = token { numberCount += 1; numberIndex = i }
        }
        guard numberCount == 1, let ni = numberIndex, case .number(let amount) = tokens[ni] else { return nil }

        // Source currency must sit directly next to the amount (prefix or suffix form).
        var source: String?
        var lo = ni
        var hi = ni
        if ni > 0, case .currency(let code) = tokens[ni - 1] { source = code; lo = ni - 1 }
        if source == nil, ni + 1 < tokens.count, case .currency(let code) = tokens[ni + 1] { source = code; hi = ni + 1 }
        guard let src = source, lo == 0 else { return nil }

        // Everything after the amount part: optional connector + optional target currency.
        var target: String?
        var idx = hi + 1
        if idx < tokens.count {
            if case .connector = tokens[idx] {
                idx += 1
                guard idx < tokens.count, case .currency(let code) = tokens[idx] else { return nil }
                target = code
                idx += 1
            } else if case .currency(let code) = tokens[idx] {
                target = code
                idx += 1
            } else {
                return nil
            }
            guard idx == tokens.count else { return nil }
        }

        let tgt = target ?? (src == local ? "USD" : local)
        guard let fromRate = rate(for: src), let toRate = rate(for: tgt), fromRate > 0, toRate > 0 else { return nil }
        let result = amount * toRate / fromRate
        guard result.isFinite else { return nil }
        let formatted: String
        if result != 0 && abs(result) < 0.05 {
            formatted = String(format: "%.4f", result)
        } else {
            formatted = String(format: "%.2f", result)
        }
        return MathResult(expression: "\(formatValue(amount)) \(src) → \(tgt)", result: "\(formatted) \(tgt)")
    }

    private static func tokenizeCurrency(_ s: String) -> [CToken]? {
        var tokens: [CToken] = []
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c.isWhitespace {
                i = s.index(after: i)
                continue
            }
            if s[i...].hasPrefix("->") || s[i...].hasPrefix("=>") {
                tokens.append(.connector)
                i = s.index(i, offsetBy: 2)
                continue
            }
            if c == "=" {
                tokens.append(.connector)
                i = s.index(after: i)
                continue
            }
            if c.isNumber || c == "." {
                if let (value, next) = matchNumber(at: i, in: s) {
                    tokens.append(.number(value))
                    i = next
                    continue
                }
                return nil
            }
            if c.isLetter {
                var j = i
                var word = ""
                while j < s.endIndex && s[j].isLetter {
                    word.append(s[j])
                    j = s.index(after: j)
                }
                if connectors.contains(word) {
                    tokens.append(.connector)
                    i = j
                    continue
                }
                if let (code, next) = matchCurrencyAlias(at: i, in: s) {
                    tokens.append(.currency(code))
                    i = next
                    continue
                }
                return nil
            }
            if let (code, next) = matchCurrencyAlias(at: i, in: s) {
                tokens.append(.currency(code))
                i = next
                continue
            }
            return nil
        }
        return tokens
    }

    /// Matches a numeric amount with optional commas/underscores and an optional k/m/b
    /// magnitude multiplier. The multiplier is only consumed when not followed by a
    /// letter, so "100kr" parses as 100 + "kr" (SEK) rather than 100k + "r".
    private static func matchNumber(at i: String.Index, in s: String) -> (Double, String.Index)? {
        var j = i
        var sawDigit = false
        while j < s.endIndex, s[j].isNumber || s[j] == "," || s[j] == "_" {
            if s[j].isNumber { sawDigit = true }
            j = s.index(after: j)
        }
        if j < s.endIndex && s[j] == "." {
            j = s.index(after: j)
            while j < s.endIndex && s[j].isNumber {
                sawDigit = true
                j = s.index(after: j)
            }
        }
        guard sawDigit else { return nil }
        let digitsEnd = j
        var multiplier = 1.0
        if j < s.endIndex, "kmb".contains(s[j]) {
            let after = s.index(after: j)
            if after == s.endIndex || !s[after].isLetter {
                switch s[j] {
                case "k": multiplier = 1e3
                case "m": multiplier = 1e6
                default: multiplier = 1e9
                }
                j = after
            }
        }
        let cleaned = String(s[i..<digitsEnd])
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "_", with: "")
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return (value * multiplier, j)
    }

    /// Longest-first alias match. Letter-only aliases require non-letter boundaries so
    /// "rp" inside "xrp" is rejected, while "100rp" / "rp100" still match.
    private static func matchCurrencyAlias(at i: String.Index, in s: String) -> (String, String.Index)? {
        for (alias, code) in currencyAliasesSorted where s[i...].hasPrefix(alias) {
            let end = s.index(i, offsetBy: alias.count)
            if alias.allSatisfy({ $0.isLetter }) {
                let prevOK = i == s.startIndex || !s[s.index(before: i)].isLetter
                let nextOK = end == s.endIndex || !s[end].isLetter
                guard prevOK && nextOK else { continue }
            }
            return (code, end)
        }
        // Any 3-letter ISO-4217 code known to the live or offline rate table.
        var j = i
        var count = 0
        while j < s.endIndex && s[j].isLetter && count < 3 {
            j = s.index(after: j)
            count += 1
        }
        if count == 3 {
            let prevOK = i == s.startIndex || !s[s.index(before: i)].isLetter
            let nextOK = j == s.endIndex || !s[j].isLetter
            if prevOK && nextOK {
                let code = String(s[i..<j]).uppercased()
                if rate(for: code) != nil { return (code, j) }
            }
        }
        return nil
    }

    // MARK: - Formatting

    /// Two decimals with trailing zeros trimmed ("1000.00" -> "1000", "4.54" stays).
    private static func formatValue(_ value: Double) -> String {
        var s = String(format: "%.2f", value)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s
    }
}
