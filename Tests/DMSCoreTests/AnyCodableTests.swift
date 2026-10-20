import Testing
import Foundation
@testable import DMSCore

@Suite("AnyCodable Comprehensive Tests")
struct AnyCodableTests {

    @Test("Literal Initializers and Direct Value Extraction")
    func testLiteralsAndValues() {
        let b: AnyCodable = true
        let i: AnyCodable = 42
        let d: AnyCodable = 3.14159
        let s: AnyCodable = "DMS Shell"
        let n: AnyCodable = nil

        #expect(b.boolValue == true)
        #expect(b.intValue == nil)
        #expect(b.stringValue == "true")

        #expect(i.intValue == 42)
        #expect(i.doubleValue == 42.0)
        #expect(i.stringValue == "42")
        #expect(i.boolValue == nil)

        #expect(d.doubleValue == 3.14159)
        #expect(d.intValue == 3)
        #expect(d.stringValue == "3.14159")
        #expect(d.boolValue == nil)

        #expect(s.stringValue == "DMS Shell")
        #expect(s.intValue == nil)
        #expect(s.doubleValue == nil)
        #expect(s.boolValue == nil)

        #expect(n.value == .null)
        #expect(n.boolValue == nil)
        #expect(n.intValue == nil)
        #expect(n.doubleValue == nil)
        #expect(n.stringValue == nil)
    }

    @Test("Coercion from Numeric Strings")
    func testStringCoercion() {
        let intString = AnyCodable("123")
        #expect(intString.intValue == 123)
        #expect(intString.doubleValue == 123.0)

        let doubleString = AnyCodable("45.67")
        #expect(doubleString.intValue == nil)
        #expect(doubleString.doubleValue == 45.67)

        let invalidString = AnyCodable("not-a-number")
        #expect(invalidString.intValue == nil)
        #expect(invalidString.doubleValue == nil)
    }

    @Test("Collections and Nested Dictionaries")
    func testCollections() {
        let arrayVal: [Any] = [1, "two", 3.0, false]
        let codableArray = AnyCodable(arrayVal)
        #expect(codableArray.arrayValue != nil)
        #expect(codableArray.arrayValue?.count == 4)
        #expect(codableArray.arrayValue?[0].intValue == 1)
        #expect(codableArray.arrayValue?[1].stringValue == "two")
        #expect(codableArray.arrayValue?[2].doubleValue == 3.0)
        #expect(codableArray.arrayValue?[3].boolValue == false)

        let dictVal: [String: Any] = [
            "title": "Control Center",
            "columns": 8,
            "visible": true
        ]
        let codableDict = AnyCodable(dictVal)
        #expect(codableDict.dictionaryValue != nil)
        #expect(codableDict.dictionaryValue?["title"]?.stringValue == "Control Center")
        #expect(codableDict.dictionaryValue?["columns"]?.intValue == 8)
        #expect(codableDict.dictionaryValue?["visible"]?.boolValue == true)
    }

    @Test("Arbitrary Object Description Fallback")
    func testFallbackDescription() {
        struct CustomStruct: CustomStringConvertible {
            var description: String { "custom_description" }
        }
        let anyVal = AnyCodable(CustomStruct())
        #expect(anyVal.stringValue == "custom_description")
    }

    @Test("JSON Encoding and Decoding Roundtrip")
    func testCodableRoundtrip() throws {
        struct Payload: Codable, Equatable {
            let nullVal: AnyCodable
            let boolVal: AnyCodable
            let intVal: AnyCodable
            let doubleVal: AnyCodable
            let strVal: AnyCodable
            let arrVal: AnyCodable
            let dictVal: AnyCodable
        }

        let original = Payload(
            nullVal: AnyCodable(nil),
            boolVal: AnyCodable(true),
            intVal: AnyCodable(-999),
            doubleVal: AnyCodable(123.456),
            strVal: AnyCodable("dynamic string"),
            arrVal: AnyCodable([AnyCodable(1), AnyCodable("sub")]),
            dictVal: AnyCodable(["nestedKey": AnyCodable("nestedVal")])
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Payload.self, from: data)

        #expect(decoded == original)
        #expect(decoded.nullVal.value == .null)
        #expect(decoded.boolVal.boolValue == true)
        #expect(decoded.intVal.intValue == -999)
        #expect(decoded.doubleVal.doubleValue == 123.456)
        #expect(decoded.strVal.stringValue == "dynamic string")
        #expect(decoded.arrVal.arrayValue?.count == 2)
        #expect(decoded.dictVal.dictionaryValue?["nestedKey"]?.stringValue == "nestedVal")
    }

    @Test("Equatable and Hashable Conformance")
    func testEqualityAndHashable() {
        let a = AnyCodable(100)
        let b = AnyCodable(100)
        let c = AnyCodable("100")
        let d = AnyCodable(100.0)

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
        #expect(a != d) // different AnySendable enum cases (int vs double)

        var set = Set<AnyCodable>()
        set.insert(a)
        set.insert(b)
        set.insert(c)
        #expect(set.count == 2)
        #expect(set.contains(a))
        #expect(set.contains(c))
    }
}
