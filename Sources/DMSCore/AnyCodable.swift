import Foundation

/// Type-erased Codable wrapper for heterogeneous JSON values in widget options and configuration schemas.
public struct AnyCodable: Sendable, Codable, Equatable, Hashable {
    public let value: AnySendable

    public enum AnySendable: Sendable, Equatable, Hashable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([AnyCodable])
        case dictionary([String: AnyCodable])
    }

    public init(_ value: Any?) {
        guard let value = value else {
            self.value = .null
            return
        }
        // Wrapping an existing AnyCodable preserves its value instead of stringifying it.
        if let codable = value as? AnyCodable {
            self.value = codable.value
            return
        }
        // Foundation NSNumber (also the bridge target of Swift numeric types):
        // distinguish a real boolean (CFBoolean) from numeric 0/1.
        if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                self.value = .bool(num.boolValue)
            } else if let i = value as? Int {
                self.value = .int(i)
            } else if let d = value as? Double {
                self.value = .double(d)
            } else {
                self.value = .double(num.doubleValue)
            }
            return
        }
        if let b = value as? Bool {
            self.value = .bool(b)
        } else if let i = value as? Int {
            self.value = .int(i)
        } else if let i32 = value as? Int32 {
            self.value = .int(Int(i32))
        } else if let i64 = value as? Int64 {
            self.value = .int(Int(clamping: i64))
        } else if let u = value as? UInt {
            self.value = .int(Int(clamping: u))
        } else if let u32 = value as? UInt32 {
            self.value = .int(Int(u32))
        } else if let f = value as? Float {
            self.value = .double(Double(f))
        } else if let d = value as? Double {
            self.value = .double(d)
        } else if let s = value as? String {
            self.value = .string(s)
        } else if let a = value as? [AnyCodable] {
            self.value = .array(a)
        } else if let a = value as? [Any] {
            self.value = .array(a.map { AnyCodable($0) })
        } else if let d = value as? [String: AnyCodable] {
            self.value = .dictionary(d)
        } else if let d = value as? [String: Any] {
            var converted: [String: AnyCodable] = [:]
            for (k, v) in d {
                converted[k] = AnyCodable(v)
            }
            self.value = .dictionary(converted)
        } else {
            self.value = .string(String(describing: value))
        }
    }

    public init(booleanLiteral value: Bool) { self.init(value) }
    public init(integerLiteral value: Int) { self.init(value) }
    public init(floatLiteral value: Double) { self.init(value) }
    public init(stringLiteral value: String) { self.init(value) }

    public var boolValue: Bool? {
        if case .bool(let b) = value { return b }
        return nil
    }

    public var intValue: Int? {
        switch value {
        case .int(let i): return i
        case .double(let d):
            // Int(Double) traps on NaN/Infinity/overflow; guard and clamp instead.
            guard d.isFinite else { return nil }
            let clamped = min(max(d, Double(Int.min)), Double(Int.max - 1024))
            return Int(clamped)
        case .string(let s): return Int(s)
        default: return nil
        }
    }

    public var doubleValue: Double? {
        switch value {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    public var stringValue: String? {
        switch value {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return String(b)
        default: return nil
        }
    }

    public var arrayValue: [AnyCodable]? {
        if case .array(let a) = value { return a }
        return nil
    }

    public var dictionaryValue: [String: AnyCodable]? {
        if case .dictionary(let d) = value { return d }
        return nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = .null
        } else if let b = try? container.decode(Bool.self) {
            self.value = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self.value = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self.value = .double(d)
        } else if let s = try? container.decode(String.self) {
            self.value = .string(s)
        } else if let a = try? container.decode([AnyCodable].self) {
            self.value = .array(a)
        } else if let d = try? container.decode([String: AnyCodable].self) {
            self.value = .dictionary(d)
        } else {
            self.value = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .int(let i):
            try container.encode(i)
        case .double(let d):
            try container.encode(d)
        case .string(let s):
            try container.encode(s)
        case .array(let a):
            try container.encode(a)
        case .dictionary(let d):
            try container.encode(d)
        }
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.value = .null
    }
}
