import Testing
import Foundation
@testable import DMSCore

@Suite("UnitConverter Unit Tests")
struct UnitConverterUnitTests {

    @Test("Length conversions")
    func lengthConversions() {
        #expect(UnitConverter.evaluate("1 mi in km")?.result == "1.61 km")
        #expect(UnitConverter.evaluate("100 cm in m")?.result == "1 m")
        #expect(UnitConverter.evaluate("10 ft in m")?.result == "3.05 m")
        #expect(UnitConverter.evaluate("1 in in cm")?.result == "2.54 cm")
        #expect(UnitConverter.evaluate("100m in ft")?.result == "328.08 ft")
        #expect(UnitConverter.evaluate("2.5m in ft")?.result == "8.2 ft")
    }

    @Test("Mass conversions")
    func massConversions() {
        #expect(UnitConverter.evaluate("1 kg in g")?.result == "1000 g")
        #expect(UnitConverter.evaluate("10 pounds in kg")?.result == "4.54 kg")
        #expect(UnitConverter.evaluate("1 lb in oz")?.result == "16 oz")
        #expect(UnitConverter.evaluate("1 st in kg")?.result == "6.35 kg")
    }

    @Test("Temperature conversions")
    func temperatureConversions() {
        #expect(UnitConverter.evaluate("100 f in c")?.result == "37.78 °C")
        #expect(UnitConverter.evaluate("0 c in f")?.result == "32 °F")
        #expect(UnitConverter.evaluate("300 k in c")?.result == "26.85 °C")
        #expect(UnitConverter.evaluate("25 celsius in fahrenheit")?.result == "77 °F")
    }

    @Test("Data conversions")
    func dataConversions() {
        #expect(UnitConverter.evaluate("1 kb in b")?.result == "1000 B")
        #expect(UnitConverter.evaluate("1 kib in b")?.result == "1024 B")
        #expect(UnitConverter.evaluate("1 gb in mb")?.result == "1000 MB")
    }

    @Test("Time conversions")
    func timeConversions() {
        #expect(UnitConverter.evaluate("1 h in min")?.result == "60 min")
        #expect(UnitConverter.evaluate("1 w in d")?.result == "7 d")
        #expect(UnitConverter.evaluate("1000 ms in s")?.result == "1 s")
        #expect(UnitConverter.evaluate("1 y in d")?.result == "365.25 d")
    }

    @Test("Speed conversions")
    func speedConversions() {
        #expect(UnitConverter.evaluate("100 kmh in mph")?.result == "62.14 mph")
        #expect(UnitConverter.evaluate("10 m/s in kmh")?.result == "36 km/h")
        #expect(UnitConverter.evaluate("1 kn in kmh")?.result == "1.85 km/h")
    }

    @Test("Volume conversions")
    func volumeConversions() {
        #expect(UnitConverter.evaluate("1 gal in l")?.result == "3.79 L")
        #expect(UnitConverter.evaluate("1 l in ml")?.result == "1000 ml")
        #expect(UnitConverter.evaluate("1 cup in ml")?.result == "236.59 ml")
    }

    @Test("Programmer base conversions")
    func baseConversions() {
        #expect(UnitConverter.evaluate("255 in hex")?.result == "0xFF")
        #expect(UnitConverter.evaluate("0xff in dec")?.result == "255")
        #expect(UnitConverter.evaluate("0b1010 in hex")?.result == "0xA")
        #expect(UnitConverter.evaluate("10 in bin")?.result == "0b1010")
        #expect(UnitConverter.evaluate("0o17 in dec")?.result == "15")
    }

    @Test("Timezone conversions")
    func timezoneConversions() {
        #expect(UnitConverter.evaluate("12:00 UTC in JST")?.result == "21:00 JST")
        #expect(UnitConverter.evaluate("00:00 PST in UTC")?.result == "08:00 UTC")
        let now = UnitConverter.evaluate("now in UTC")?.result
        #expect(now?.range(of: #"^\d{2}:\d{2} UTC$"#, options: .regularExpression) != nil)
    }

    @Test("Bare numbers and non-conversions return nil")
    func nonConversions() {
        #expect(UnitConverter.evaluate("100") == nil)
        #expect(UnitConverter.evaluate("100k") == nil)
        #expect(UnitConverter.evaluate("") == nil)
        #expect(UnitConverter.evaluate("hello world") == nil)
    }
}

@Suite("UnitConverter Offline Currency Tests")
struct UnitConverterOfflineCurrencyTests {

    @Test("Offline fallback rate table")
    func offlineRateTable() {
        #expect(UnitConverter.offlineCurrencyRates.count == 46)
        #expect(UnitConverter.offlineCurrencyRates["USD"] == 1.0)
        #expect(UnitConverter.offlineCurrencyRates["EUR"] == 0.92)
        #expect(UnitConverter.offlineCurrencyRates["GBP"] == 0.79)
        #expect(UnitConverter.offlineCurrencyRates["CHF"] == 0.88)
        #expect(UnitConverter.offlineCurrencyRates["JPY"] == 149.0)
        #expect(UnitConverter.rate(for: "USD") == 1.0)
        #expect(UnitConverter.rate(for: "jpy") == 149.0)
        #expect(UnitConverter.rate(for: "XXX") == nil)
    }

    @Test("Classic offline currency conversions")
    func classicCurrencyConversions() {
        #expect(UnitConverter.evaluate("100 usd in eur")?.result == "92.00 EUR")
        #expect(UnitConverter.evaluate("50 eur in usd")?.result == "54.35 USD")
        #expect(UnitConverter.evaluate("1000 jpy in usd")?.result == "6.71 USD")
        #expect(UnitConverter.evaluate("10 chf to gbp")?.result == "8.98 GBP")
    }

    @Test("Suffix symbol + connector + target")
    func suffixSymbolConversions() {
        #expect(UnitConverter.evaluate("100$ in €")?.result == "92.00 EUR")
        #expect(UnitConverter.evaluate("50€ to $")?.result == "54.35 USD")
        #expect(UnitConverter.evaluate("25£ -> €")?.result == "29.11 EUR")
        #expect(UnitConverter.evaluate("1000¥ in usd")?.result == "6.71 USD")
        #expect(UnitConverter.evaluate("100zł in eur")?.result == "23.00 EUR")
        #expect(UnitConverter.evaluate("500₹ to usd")?.result == "6.02 USD")
    }

    @Test("Prefix symbol + connector + target")
    func prefixSymbolConversions() {
        #expect(UnitConverter.evaluate("$100 in €")?.result == "92.00 EUR")
        #expect(UnitConverter.evaluate("€50 to $")?.result == "54.35 USD")
        #expect(UnitConverter.evaluate("C$50 in €")?.result == "33.82 EUR")
        #expect(UnitConverter.evaluate("CA$100 to rmb")?.result == "529.41 CNY")
        #expect(UnitConverter.evaluate("A$100 in €")?.result == "60.53 EUR")
        #expect(UnitConverter.evaluate("Rp100k in €")?.result == "5.68 EUR")
        #expect(UnitConverter.evaluate("Rp 100,000 to eur")?.result == "5.68 EUR")
        #expect(UnitConverter.evaluate("RM 50 in usd")?.result == "11.24 USD")
        #expect(UnitConverter.evaluate("CHF 100 in €")?.result == "104.55 EUR")
    }

    @Test("Code/alias + connector + target")
    func codeAliasConversions() {
        #expect(UnitConverter.evaluate("100k rp in €")?.result == "5.68 EUR")
        #expect(UnitConverter.evaluate("100000 rp to eur")?.result == "5.68 EUR")
        #expect(UnitConverter.evaluate("100000 idr in usd")?.result == "6.17 USD")
        #expect(UnitConverter.evaluate("100 rp in €")?.result == "0.0057 EUR")
        #expect(UnitConverter.evaluate("500 rmb in cad")?.result == "94.44 CAD")
        #expect(UnitConverter.evaluate("500 rmb to €")?.result == "63.89 EUR")
        #expect(UnitConverter.evaluate("100 yuan in usd")?.result == "13.89 USD")
        #expect(UnitConverter.evaluate("100 cad in rmb")?.result == "529.41 CNY")
        #expect(UnitConverter.evaluate("100 cad -> usd")?.result == "73.53 USD")
        #expect(UnitConverter.evaluate("100 usd -> €")?.result == "92.00 EUR")
        #expect(UnitConverter.evaluate("100 usd = €")?.result == "92.00 EUR")
    }

    @Test("Connectorless two-part shorthand")
    func connectorlessShorthand() {
        #expect(UnitConverter.evaluate("100$ €")?.result == "92.00 EUR")
        #expect(UnitConverter.evaluate("$100 €")?.result == "92.00 EUR")
        #expect(UnitConverter.evaluate("100 usd eur")?.result == "92.00 EUR")
        #expect(UnitConverter.evaluate("500 rmb cad")?.result == "94.44 CAD")
        #expect(UnitConverter.evaluate("100k rp eur")?.result == "5.68 EUR")
        #expect(UnitConverter.evaluate("100 cad €")?.result == "67.65 EUR")
    }

    @Test("Implicit local currency target")
    func implicitLocalCurrency() {
        #expect(UnitConverter.evaluate("100$", defaultLocalCurrency: "EUR")?.result == "92.00 EUR")
        #expect(UnitConverter.evaluate("$100", defaultLocalCurrency: "EUR")?.result == "92.00 EUR")
        #expect(UnitConverter.evaluate("100€", defaultLocalCurrency: "EUR")?.result == "108.70 USD")
        #expect(UnitConverter.evaluate("50€", defaultLocalCurrency: "USD")?.result == "54.35 USD")
        #expect(UnitConverter.evaluate("500 rmb", defaultLocalCurrency: "EUR")?.result == "63.89 EUR")
        #expect(UnitConverter.evaluate("100k rp", defaultLocalCurrency: "EUR")?.result == "5.68 EUR")
        #expect(UnitConverter.evaluate("Rp 100000", defaultLocalCurrency: "USD")?.result == "6.17 USD")
        #expect(UnitConverter.evaluate("100 cad", defaultLocalCurrency: "EUR")?.result == "67.65 EUR")
        #expect(UnitConverter.evaluate("C$50", defaultLocalCurrency: "EUR")?.result == "33.82 EUR")
        #expect(UnitConverter.evaluate("£25", defaultLocalCurrency: "EUR")?.result == "29.11 EUR")
        #expect(UnitConverter.evaluate("5000¥", defaultLocalCurrency: "EUR")?.result == "30.87 EUR")
    }

    @Test("Magnitude multipliers and thousands separators")
    func magnitudeMultipliers() {
        #expect(UnitConverter.evaluate("1,500 usd in eur")?.result == "1380.00 EUR")
        #expect(UnitConverter.evaluate("2.5m usd in eur")?.result == "2300000.00 EUR")
        #expect(UnitConverter.evaluate("1.2b usd in jpy")?.result == "178800000000.00 JPY")
        #expect(UnitConverter.evaluate("1_000 eur in usd")?.result == "1086.96 USD")
        // Multipliers must NOT apply to length units: 100m is 100 meters, not 100 mega.
        #expect(UnitConverter.evaluate("100m in ft")?.result == "328.08 ft")
    }

    @Test("Pound disambiguation: mass vs GBP")
    func poundDisambiguation() {
        #expect(UnitConverter.evaluate("10 pounds in kg")?.result == "4.54 kg")
        #expect(UnitConverter.evaluate("10 pounds in eur")?.result == "11.65 EUR")
    }
}

@Suite("UnitConverter Currency Alias Resolver")
struct UnitConverterAliasTests {

    @Test("Symbols and aliases resolve to ISO codes")
    func aliasResolution() {
        #expect(UnitConverter.resolveCurrency("$") == "USD")
        #expect(UnitConverter.resolveCurrency("US$") == "USD")
        #expect(UnitConverter.resolveCurrency("usd") == "USD")
        #expect(UnitConverter.resolveCurrency("dollar") == "USD")
        #expect(UnitConverter.resolveCurrency("dollars") == "USD")
        #expect(UnitConverter.resolveCurrency("buck") == "USD")
        #expect(UnitConverter.resolveCurrency("bucks") == "USD")
        #expect(UnitConverter.resolveCurrency("€") == "EUR")
        #expect(UnitConverter.resolveCurrency("eur") == "EUR")
        #expect(UnitConverter.resolveCurrency("euro") == "EUR")
        #expect(UnitConverter.resolveCurrency("euros") == "EUR")
        #expect(UnitConverter.resolveCurrency("£") == "GBP")
        #expect(UnitConverter.resolveCurrency("gbp") == "GBP")
        #expect(UnitConverter.resolveCurrency("pound") == "GBP")
        #expect(UnitConverter.resolveCurrency("pounds") == "GBP")
        #expect(UnitConverter.resolveCurrency("quid") == "GBP")
        #expect(UnitConverter.resolveCurrency("sterling") == "GBP")
        #expect(UnitConverter.resolveCurrency("¥") == "JPY")
        #expect(UnitConverter.resolveCurrency("jpy") == "JPY")
        #expect(UnitConverter.resolveCurrency("yen") == "JPY")
        #expect(UnitConverter.resolveCurrency("rmb") == "CNY")
        #expect(UnitConverter.resolveCurrency("cny") == "CNY")
        #expect(UnitConverter.resolveCurrency("yuan") == "CNY")
        #expect(UnitConverter.resolveCurrency("renminbi") == "CNY")
        #expect(UnitConverter.resolveCurrency("cn¥") == "CNY")
        #expect(UnitConverter.resolveCurrency("rp") == "IDR")
        #expect(UnitConverter.resolveCurrency("idr") == "IDR")
        #expect(UnitConverter.resolveCurrency("rupiah") == "IDR")
        #expect(UnitConverter.resolveCurrency("cad") == "CAD")
        #expect(UnitConverter.resolveCurrency("c$") == "CAD")
        #expect(UnitConverter.resolveCurrency("ca$") == "CAD")
        #expect(UnitConverter.resolveCurrency("can$") == "CAD")
        #expect(UnitConverter.resolveCurrency("canadian dollar") == "CAD")
        #expect(UnitConverter.resolveCurrency("canadian dollars") == "CAD")
        #expect(UnitConverter.resolveCurrency("loonie") == "CAD")
        #expect(UnitConverter.resolveCurrency("aud") == "AUD")
        #expect(UnitConverter.resolveCurrency("a$") == "AUD")
        #expect(UnitConverter.resolveCurrency("au$") == "AUD")
        #expect(UnitConverter.resolveCurrency("nzd") == "NZD")
        #expect(UnitConverter.resolveCurrency("nz$") == "NZD")
        #expect(UnitConverter.resolveCurrency("hkd") == "HKD")
        #expect(UnitConverter.resolveCurrency("hk$") == "HKD")
        #expect(UnitConverter.resolveCurrency("sgd") == "SGD")
        #expect(UnitConverter.resolveCurrency("s$") == "SGD")
        #expect(UnitConverter.resolveCurrency("twd") == "TWD")
        #expect(UnitConverter.resolveCurrency("nt$") == "TWD")
        #expect(UnitConverter.resolveCurrency("brl") == "BRL")
        #expect(UnitConverter.resolveCurrency("r$") == "BRL")
        #expect(UnitConverter.resolveCurrency("real") == "BRL")
        #expect(UnitConverter.resolveCurrency("reais") == "BRL")
        #expect(UnitConverter.resolveCurrency("mxn") == "MXN")
        #expect(UnitConverter.resolveCurrency("mx$") == "MXN")
        #expect(UnitConverter.resolveCurrency("peso") == "MXN")
        #expect(UnitConverter.resolveCurrency("pesos") == "MXN")
        #expect(UnitConverter.resolveCurrency("chf") == "CHF")
        #expect(UnitConverter.resolveCurrency("sfr") == "CHF")
        #expect(UnitConverter.resolveCurrency("franc") == "CHF")
        #expect(UnitConverter.resolveCurrency("francs") == "CHF")
        #expect(UnitConverter.resolveCurrency("krw") == "KRW")
        #expect(UnitConverter.resolveCurrency("₩") == "KRW")
        #expect(UnitConverter.resolveCurrency("won") == "KRW")
        #expect(UnitConverter.resolveCurrency("inr") == "INR")
        #expect(UnitConverter.resolveCurrency("₹") == "INR")
        #expect(UnitConverter.resolveCurrency("rupee") == "INR")
        #expect(UnitConverter.resolveCurrency("rupees") == "INR")
        #expect(UnitConverter.resolveCurrency("myr") == "MYR")
        #expect(UnitConverter.resolveCurrency("rm") == "MYR")
        #expect(UnitConverter.resolveCurrency("ringgit") == "MYR")
        #expect(UnitConverter.resolveCurrency("thb") == "THB")
        #expect(UnitConverter.resolveCurrency("฿") == "THB")
        #expect(UnitConverter.resolveCurrency("baht") == "THB")
        #expect(UnitConverter.resolveCurrency("vnd") == "VND")
        #expect(UnitConverter.resolveCurrency("₫") == "VND")
        #expect(UnitConverter.resolveCurrency("dong") == "VND")
        #expect(UnitConverter.resolveCurrency("php") == "PHP")
        #expect(UnitConverter.resolveCurrency("₱") == "PHP")
        #expect(UnitConverter.resolveCurrency("pln") == "PLN")
        #expect(UnitConverter.resolveCurrency("zł") == "PLN")
        #expect(UnitConverter.resolveCurrency("zl") == "PLN")
        #expect(UnitConverter.resolveCurrency("zloty") == "PLN")
        #expect(UnitConverter.resolveCurrency("try") == "TRY")
        #expect(UnitConverter.resolveCurrency("₺") == "TRY")
        #expect(UnitConverter.resolveCurrency("lira") == "TRY")
        #expect(UnitConverter.resolveCurrency("rub") == "RUB")
        #expect(UnitConverter.resolveCurrency("₽") == "RUB")
        #expect(UnitConverter.resolveCurrency("ruble") == "RUB")
        #expect(UnitConverter.resolveCurrency("rubles") == "RUB")
        #expect(UnitConverter.resolveCurrency("ils") == "ILS")
        #expect(UnitConverter.resolveCurrency("₪") == "ILS")
        #expect(UnitConverter.resolveCurrency("shekel") == "ILS")
        #expect(UnitConverter.resolveCurrency("shekels") == "ILS")
        #expect(UnitConverter.resolveCurrency("zar") == "ZAR")
        #expect(UnitConverter.resolveCurrency("rand") == "ZAR")
        #expect(UnitConverter.resolveCurrency("sek") == "SEK")
        #expect(UnitConverter.resolveCurrency("kr") == "SEK")
        #expect(UnitConverter.resolveCurrency("krona") == "SEK")
    }

    @Test("Any 3-letter ISO code in the rate table resolves; unknown strings do not")
    func isoCodeResolution() {
        #expect(UnitConverter.resolveCurrency("EUR") == "EUR")
        #expect(UnitConverter.resolveCurrency("kes") == "KES")
        #expect(UnitConverter.resolveCurrency("ngn") == "NGN")
        #expect(UnitConverter.resolveCurrency("xyz") == nil)
        #expect(UnitConverter.resolveCurrency("") == nil)
    }
}

/// Live-rate tests use XAU (not in the offline table) so they can never race parallel
/// tests that rely on USD/EUR/GBP/JPY/CHF offline rates. Serialized among themselves.
@Suite("UnitConverter Live FX Rates", .serialized)
struct UnitConverterLiveRateTests {

    @Test("Live rates override lookup, filter invalid values, uppercase keys")
    func liveRateOverride() {
        UnitConverter.updateLiveCurrencyRates(["xau": 2400.0, "neg": -5.0, "zero": 0.0, "nan": .nan, "inf": .infinity])
        defer { UnitConverter.resetLiveCurrencyRates() }
        #expect(UnitConverter.hasLiveCurrencyRates)
        #expect(UnitConverter.rate(for: "XAU") == 2400.0)
        #expect(UnitConverter.rate(for: "NEG") == nil)
        #expect(UnitConverter.rate(for: "ZERO") == nil)
        #expect(UnitConverter.rate(for: "NAN") == nil)
        #expect(UnitConverter.rate(for: "INF") == nil)
        // Offline fallback still intact alongside live rates.
        #expect(UnitConverter.rate(for: "usd") == 1.0)
        #expect(UnitConverter.evaluate("100 usd in eur")?.result == "92.00 EUR")
        // XAU is not in the offline table, so this only works via the live rate.
        #expect(UnitConverter.evaluate("10 xau in usd")?.result == "0.0042 USD")
        #expect(UnitConverter.evaluate("4800 xau in usd")?.result == "2.00 USD")
    }

    @Test("Reset clears live rates")
    func resetClearsLiveRates() {
        UnitConverter.updateLiveCurrencyRates(["XAU": 2400.0])
        #expect(UnitConverter.hasLiveCurrencyRates)
        #expect(UnitConverter.rate(for: "XAU") == 2400.0)
        UnitConverter.resetLiveCurrencyRates()
        #expect(!UnitConverter.hasLiveCurrencyRates)
        #expect(UnitConverter.rate(for: "XAU") == nil)
        #expect(UnitConverter.evaluate("10 xau in usd") == nil)
    }
}
