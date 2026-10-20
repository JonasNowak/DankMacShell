import Foundation

/// Material Design 3 HCT (Hue, Chroma, Tone) and CAM16 color space implementation.
/// Ported verbatim from upstream DankMaterialShell (`dank-qml-common/DCommon/Common/Hct.js`),
/// based on Google Material Color Utilities.
public struct HCT: Sendable, Equatable, Hashable {
    public var hue: Double      // 0 .. 360
    public var chroma: Double   // 0 .. ~130
    public var tone: Double     // 0 .. 100

    public init(hue: Double, chroma: Double, tone: Double) {
        self.hue = HCTMath.sanitizeDegrees(hue)
        self.chroma = max(0.0, chroma)
        self.tone = min(100.0, max(0.0, tone))
    }

    /// Converts an RGB M3Color to HCT coordinates.
    public static func from(color: M3Color) -> HCT {
        let (h, c, t) = HCTMath.toHct(r: color.red, g: color.green, b: color.blue)
        return HCT(hue: h, chroma: c, tone: t)
    }

    /// Converts HCT coordinates to an RGB M3Color using CAM16 solver.
    public func toColor() -> M3Color {
        return HCTMath.fromHct(hue: hue, chroma: chroma, tone: tone)
    }

    /// Direct solver helper.
    public static func solve(hue: Double, chroma: Double, tone: Double) -> M3Color {
        return HCTMath.fromHct(hue: hue, chroma: chroma, tone: tone)
    }
}

/// Upstream CAM16 and HCT numerical algorithms.
public enum HCTMath: Sendable {

    private struct ViewingConditions {
        static let n: Double = 0.18418651851244416
        static let aw: Double = 29.98099719444734
        static let nbb: Double = 1.0169191804458757
        static let ncb: Double = 1.0169191804458757
        static let c: Double = 0.69
        static let nc: Double = 1.0
        static let rgbD: [Double] = [1.02117770275752, 0.9863077294280124, 0.9339605082802299]
        static let fl: Double = 0.3884814537800353
        static let fLRoot: Double = 0.7894826179304937
        static let z: Double = 1.909169568483652
    }

    private static let SCALED_DISCOUNT_FROM_LINRGB: [[Double]] = [
        [0.001200833568784504, 0.002389694492170889, 0.0002795742885861124],
        [0.0005891086651375999, 0.0029785502573438758, 0.0003270666104008398],
        [0.00010146692491640572, 0.0005364214359186694, 0.0032979401770712076]
    ]

    private static let LINRGB_FROM_SCALED_DISCOUNT: [[Double]] = [
        [1373.2198709594231, -1100.4251190754821, -7.278681089101213],
        [-271.815969077903, 559.6580465940733, -32.46047482791194],
        [1.9622899599665666, -57.173814538844006, 308.7233197812385]
    ]

    private static let Y_FROM_LINRGB: [Double] = [0.2126, 0.7152, 0.0722]

    private static let CRITICAL_PLANES: [Double] = [
        0.015176349177441876, 0.045529047532325624, 0.07588174588720938, 0.10623444424209313,
        0.13658714259697685, 0.16693984095186062, 0.19729253930674434, 0.2276452376616281,
        0.2579979360165119, 0.28835063437139563, 0.3188300904430532, 0.350925934958123,
        0.3848314933096426, 0.42057480301049466, 0.458183274052838, 0.4976837250274023,
        0.5391024159806381, 0.5824650784040898, 0.6277969426914107, 0.6751227633498623,
        0.7244668422128921, 0.775853049866786, 0.829304845476233, 0.8848452951698498,
        0.942497089126609, 1.0022825574869039, 1.0642236851973577, 1.1283421258858297,
        1.1946592148522128, 1.2631959812511864, 1.3339731595349034, 1.407011200216447,
        1.4823302800086415, 1.5599503113873272, 1.6398909516233677, 1.7221716113234105,
        1.8068114625156377, 1.8938294463134073, 1.9832442801866852, 2.075074464868551,
        2.1693382909216234, 2.2660538449872063, 2.36523901573795, 2.4669114995532007,
        2.5710888059345764, 2.6777882626779785, 2.7870270208169257, 2.898822059350997,
        3.0131901897720907, 3.1301480604002863, 3.2497121605402226, 3.3718988244681087,
        3.4967242352587946, 3.624204428461639, 3.754355295633311, 3.887192587735158,
        4.022731918402185, 4.160988767090289, 4.301978482107941, 4.445716283538092,
        4.592217266055746, 4.741496401646282, 4.893568542229298, 5.048448422192488,
        5.20615066083972, 5.3666897647573375, 5.5300801301023865, 5.696336044816294,
        5.865471690767354, 6.037501145825082, 6.212438385869475, 6.390297286737924,
        6.571091626112461, 6.7548350853498045, 6.941541251256611, 7.131223617812143,
        7.323895587840543, 7.5195704746346665, 7.7182615035334345, 7.919981813454504,
        8.124744458384042, 8.332562408825165, 8.543448553206703, 8.757415699253682,
        8.974476575321063, 9.194643831691977, 9.417930041841839, 9.644347703669503,
        9.873909240696694, 10.106627003236781, 10.342513269534024, 10.58158024687427,
        10.8238400726681, 11.069304815507364, 11.317986476196008, 11.569896988756009,
        11.825048221409341, 12.083451977536606, 12.345119996613247, 12.610063955123938,
        12.878295467455942, 13.149826086772048, 13.42466730586372, 13.702830557985108,
        13.984327217668513, 14.269168601521828, 14.55736596900856, 14.848930523210871,
        15.143873411576273, 15.44220572664832, 15.743938506781891, 16.04908273684337,
        16.35764934889634, 16.66964922287304, 16.985093187232053, 17.30399201960269,
        17.62635644741625, 17.95219714852476, 18.281524751807332, 18.614349837764564,
        18.95068293910138, 19.290534541298456, 19.633915083172692, 19.98083495742689,
        20.331304511189067, 20.685334046541502, 21.042933821039977, 21.404114048223256,
        21.76888489811322, 22.137256497705877, 22.50923893145328, 22.884842241736916,
        23.264076429332462, 23.6469514538663, 24.033477234264016, 24.42366364919083,
        24.817520537484558, 25.21505769858089, 25.61628489293138, 26.021211842414342,
        26.429848230738664, 26.842203703840827, 27.258287870275353, 27.678110301598522,
        28.10168053274597, 28.529008062403893, 28.96010235337422, 29.39497283293396,
        29.83362889318845, 30.276079891419332, 30.722335150426627, 31.172403958865512,
        31.62629557157785, 32.08401920991837, 32.54558406207592, 33.010999283389665,
        33.4802739966603, 33.953417292456834, 34.430438229418264, 34.911345834551085,
        35.39614910352207, 35.88485700094671, 36.37747846067349, 36.87402238606382,
        37.37449765026789, 37.87891309649659, 38.38727753828926, 38.89959975977785,
        39.41588851594697, 39.93615253289054, 40.460400508064545, 40.98864111053629,
        41.520882981230194, 42.05713473317016, 42.597404951718396, 43.141702194811224,
        43.6900349931913, 44.24241185063697, 44.798841244188324, 45.35933162437017,
        45.92389141541209, 46.49252901546552, 47.065252796817916, 47.64207110610409,
        48.22299226451468, 48.808024568002054, 49.3971762874833, 49.9904556690408,
        50.587870934119984, 51.189430279724725, 51.79514187861014, 52.40501387947288,
        53.0190544071392, 53.637271562750364, 54.259673423945976, 54.88626804504493,
        55.517063457223934, 56.15206766869424, 56.79128866487574, 57.43473440856916,
        58.08241284012621, 58.734331877617365, 59.39049941699807, 60.05092333227251,
        60.715611475655585, 61.38457167773311, 62.057811747619894, 62.7353394731159,
        63.417162620860914, 64.10328893648692, 64.79372614476921, 65.48848194977529,
        66.18756403501224, 66.89098006357258, 67.59873767827808, 68.31084450182222,
        69.02730813691093, 69.74813616640164, 70.47333615344107, 71.20291564160104,
        71.93688215501312, 72.67524319850172, 73.41800625771542, 74.16517879925733,
        74.9167682708136, 75.67278210128072, 76.43322770089146, 77.1981124613393,
        77.96744375590167, 78.74122893956174, 79.51947534912904, 80.30219030335869,
        81.08938110306934, 81.88105503125999, 82.67721935322541, 83.4778813166706,
        84.28304815182372, 85.09272707154808, 85.90692527145302, 86.72564993000343,
        87.54890820862819, 88.3767072518277, 89.2090541872801, 90.04595612594655,
        90.88742016217518, 91.73345337380438, 92.58406282226491, 93.43925555268066,
        94.29903859396902, 95.16341895893969, 96.03240364439274, 96.9059996312159,
        97.78421388448044, 98.6670533535366, 99.55452497210776
    ]

    public static func signum(_ value: Double) -> Double {
        if value < 0 { return -1.0 }
        if value == 0 { return 0.0 }
        return 1.0
    }

    public static func sanitizeDegrees(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360.0)
        return wrapped < 0 ? wrapped + 360.0 : wrapped
    }

    public static func rotationDirection(from: Double, to: Double) -> Double {
        return sanitizeDegrees(to - from) <= 180.0 ? 1.0 : -1.0
    }

    public static func differenceDegrees(_ a: Double, _ b: Double) -> Double {
        return 180.0 - abs(abs(a - b) - 180.0)
    }

    private static func matrixMultiply(_ row: [Double], _ matrix: [[Double]]) -> [Double] {
        return [
            row[0] * matrix[0][0] + row[1] * matrix[0][1] + row[2] * matrix[0][2],
            row[0] * matrix[1][0] + row[1] * matrix[1][1] + row[2] * matrix[1][2],
            row[0] * matrix[2][0] + row[1] * matrix[2][1] + row[2] * matrix[2][2]
        ]
    }

    public static func labF(_ t: Double) -> Double {
        return t > (216.0 / 24389.0) ? cbrt(t) : (24389.0 / 27.0 * t + 16.0) / 116.0
    }

    public static func labInvf(_ ft: Double) -> Double {
        let cubed = ft * ft * ft
        return cubed > (216.0 / 24389.0) ? cubed : (116.0 * ft - 16.0) / (24389.0 / 27.0)
    }

    public static func yFromTone(_ tone: Double) -> Double {
        return 100.0 * labInvf((tone + 16.0) / 116.0)
    }

    public static func toneFromY(_ y: Double) -> Double {
        return labF(y / 100.0) * 116.0 - 16.0
    }

    public static func linearized(_ channel: Double) -> Double {
        let normalized = channel / 255.0
        if normalized <= 0.040449936 {
            return normalized / 12.92 * 100.0
        }
        return pow((normalized + 0.055) / 1.055, 2.4) * 100.0
    }

    public static func delinearized(_ channel: Double) -> Double {
        let normalized = channel / 100.0
        let value = normalized <= 0.0031308 ? normalized * 12.92 : 1.055 * pow(normalized, 1.0 / 2.4) - 0.055
        return min(255.0, max(0.0, round(value * 255.0)))
    }

    private static func trueDelinearized(_ channel: Double) -> Double {
        let normalized = channel / 100.0
        let value = normalized <= 0.0031308 ? normalized * 12.92 : 1.055 * pow(normalized, 1.0 / 2.4) - 0.055
        return value * 255.0
    }

    private static func colorFromLinrgb(_ linrgb: [Double]) -> M3Color {
        return M3Color.from(
            r: delinearized(linrgb[0]) / 255.0,
            g: delinearized(linrgb[1]) / 255.0,
            b: delinearized(linrgb[2]) / 255.0
        )
    }

    private static func colorFromTone(_ tone: Double) -> M3Color {
        let component = delinearized(yFromTone(tone)) / 255.0
        return M3Color.from(r: component, g: component, b: component)
    }

    private static func chromaticAdaptation(_ component: Double) -> Double {
        let af = pow(abs(component), 0.42)
        return signum(component) * 400.0 * af / (af + 27.13)
    }

    private static func inverseChromaticAdaptation(_ adapted: Double) -> Double {
        let adaptedAbs = abs(adapted)
        let base = max(0.0, 27.13 * adaptedAbs / (400.0 - adaptedAbs))
        return signum(adapted) * pow(base, 1.0 / 0.42)
    }

    private static func hueOf(_ linrgb: [Double]) -> Double {
        let scaledDiscount = matrixMultiply(linrgb, SCALED_DISCOUNT_FROM_LINRGB)
        let rA = chromaticAdaptation(scaledDiscount[0])
        let gA = chromaticAdaptation(scaledDiscount[1])
        let bA = chromaticAdaptation(scaledDiscount[2])
        return atan2((rA + gA - 2.0 * bA) / 9.0, (11.0 * rA - 12.0 * gA + bA) / 11.0)
    }

    private static func sanitizeRadians(_ angle: Double) -> Double {
        let twoPi = Double.pi * 2.0
        let rem = (angle + Double.pi * 8.0).truncatingRemainder(dividingBy: twoPi)
        return rem < 0 ? rem + twoPi : rem
    }

    private static func areInCyclicOrder(_ a: Double, _ b: Double, _ c: Double) -> Bool {
        return sanitizeRadians(b - a) < sanitizeRadians(c - a)
    }

    private static func lerpPoint(_ source: [Double], _ t: Double, _ target: [Double]) -> [Double] {
        return [
            source[0] + (target[0] - source[0]) * t,
            source[1] + (target[1] - source[1]) * t,
            source[2] + (target[2] - source[2]) * t
        ]
    }

    private static func setCoordinate(_ source: [Double], _ coordinate: Double, _ target: [Double], _ axis: Int) -> [Double] {
        let t = (coordinate - source[axis]) / (target[axis] - source[axis])
        return lerpPoint(source, t, target)
    }

    private static func isBounded(_ x: Double) -> Bool {
        return x >= 0.0 && x <= 100.0
    }

    private static func nthVertex(_ y: Double, _ n: Int) -> [Double] {
        let kR = Y_FROM_LINRGB[0]
        let kG = Y_FROM_LINRGB[1]
        let kB = Y_FROM_LINRGB[2]
        let coordA: Double = (n % 4 <= 1) ? 0.0 : 100.0
        let coordB: Double = (n % 2 == 0) ? 0.0 : 100.0
        if n < 4 {
            let r = (y - coordA * kG - coordB * kB) / kR
            return isBounded(r) ? [r, coordA, coordB] : [-1.0, -1.0, -1.0]
        }
        if n < 8 {
            let g = (y - coordB * kR - coordA * kB) / kG
            return isBounded(g) ? [coordB, g, coordA] : [-1.0, -1.0, -1.0]
        }
        let b = (y - coordA * kR - coordB * kG) / kB
        return isBounded(b) ? [coordA, coordB, b] : [-1.0, -1.0, -1.0]
    }

    private static func bisectToSegment(_ y: Double, _ targetHue: Double) -> ([Double], [Double]) {
        var left = [-1.0, -1.0, -1.0]
        var right = left
        var leftHue = 0.0
        var rightHue = 0.0
        var initialized = false
        var uncut = true
        for n in 0..<12 {
            let mid = nthVertex(y, n)
            if mid[0] < 0 { continue }
            let midHue = hueOf(mid)
            if !initialized {
                left = mid
                right = mid
                leftHue = midHue
                rightHue = midHue
                initialized = true
                continue
            }
            if !uncut && !areInCyclicOrder(leftHue, midHue, rightHue) {
                continue
            }
            uncut = false
            if areInCyclicOrder(leftHue, targetHue, midHue) {
                right = mid
                rightHue = midHue
                continue
            }
            left = mid
            leftHue = midHue
        }
        return (left, right)
    }

    private static func bisectToLimit(_ y: Double, _ targetHue: Double) -> [Double] {
        let segment = bisectToSegment(y, targetHue)
        var left = segment.0
        var leftHue = hueOf(left)
        var right = segment.1
        for axis in 0..<3 {
            if left[axis] == right[axis] { continue }
            var lPlane: Int
            var rPlane: Int
            if left[axis] < right[axis] {
                lPlane = Int(floor(trueDelinearized(left[axis]) - 0.5))
                rPlane = Int(ceil(trueDelinearized(right[axis]) - 0.5))
            } else {
                lPlane = Int(ceil(trueDelinearized(left[axis]) - 0.5))
                rPlane = Int(floor(trueDelinearized(right[axis]) - 0.5))
            }
            for _ in 0..<8 {
                if abs(rPlane - lPlane) <= 1 { break }
                let mPlane = (lPlane + rPlane) / 2
                guard mPlane >= 0 && mPlane < CRITICAL_PLANES.count else { break }
                let mid = setCoordinate(left, CRITICAL_PLANES[mPlane], right, axis)
                let midHue = hueOf(mid)
                if areInCyclicOrder(leftHue, targetHue, midHue) {
                    right = mid
                    rPlane = mPlane
                    continue
                }
                left = mid
                leftHue = midHue
                lPlane = mPlane
            }
        }
        return [(left[0] + right[0]) / 2.0, (left[1] + right[1]) / 2.0, (left[2] + right[2]) / 2.0]
    }

    private static func findResultByJ(_ hueRadians: Double, _ chroma: Double, _ y: Double) -> M3Color? {
        var j = sqrt(y) * 11.0
        let tInnerCoeff = 1.0 / pow(1.64 - pow(0.29, ViewingConditions.n), 0.73)
        let eHue = 0.25 * (cos(hueRadians + 2.0) + 3.8)
        let p1 = eHue * (50000.0 / 13.0) * ViewingConditions.nc * ViewingConditions.ncb
        let hSin = sin(hueRadians)
        let hCos = cos(hueRadians)
        for round in 0..<5 {
            let jNormalized = j / 100.0
            let alpha = (chroma == 0.0 || j == 0.0) ? 0.0 : chroma / sqrt(jNormalized)
            let t = pow(alpha * tInnerCoeff, 1.0 / 0.9)
            let ac = ViewingConditions.aw * pow(jNormalized, 1.0 / ViewingConditions.c / ViewingConditions.z)
            let p2 = ac / ViewingConditions.nbb
            let gamma = 23.0 * (p2 + 0.305) * t / (23.0 * p1 + 11.0 * t * hCos + 108.0 * t * hSin)
            let a = gamma * hCos
            let b = gamma * hSin
            let rA = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0
            let gA = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0
            let bA = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0
            let linrgb = matrixMultiply(
                [inverseChromaticAdaptation(rA), inverseChromaticAdaptation(gA), inverseChromaticAdaptation(bA)],
                LINRGB_FROM_SCALED_DISCOUNT
            )
            if linrgb[0] < 0 || linrgb[1] < 0 || linrgb[2] < 0 { return nil }
            let fnj = Y_FROM_LINRGB[0] * linrgb[0] + Y_FROM_LINRGB[1] * linrgb[1] + Y_FROM_LINRGB[2] * linrgb[2]
            if fnj <= 0 { return nil }
            if round == 4 || abs(fnj - y) < 0.002 {
                if linrgb[0] > 100.01 || linrgb[1] > 100.01 || linrgb[2] > 100.01 { return nil }
                return colorFromLinrgb(linrgb)
            }
            j = j - (fnj - y) * j / (2.0 * fnj)
        }
        return nil
    }

    /// Converts HCT (Hue, Chroma, Tone) to an RGB M3Color.
    public static func fromHct(hue: Double, chroma: Double, tone: Double) -> M3Color {
        if chroma < 0.0001 || tone < 0.0001 || tone > 99.9999 {
            return colorFromTone(tone)
        }
        let hueRadians = sanitizeDegrees(hue) / 180.0 * Double.pi
        let y = yFromTone(tone)
        if let exact = findResultByJ(hueRadians, chroma, y) {
            return exact
        }
        return colorFromLinrgb(bisectToLimit(y, hueRadians))
    }

    /// Converts RGB components (0..1) to HCT tuple (hue, chroma, tone).
    public static func toHct(r: Double, g: Double, b: Double) -> (hue: Double, chroma: Double, tone: Double) {
        let redL = linearized(r * 255.0)
        let greenL = linearized(g * 255.0)
        let blueL = linearized(b * 255.0)
        let x = 0.41233895 * redL + 0.35762064 * greenL + 0.18051042 * blueL
        let y = 0.2126 * redL + 0.7152 * greenL + 0.0722 * blueL
        let z = 0.01932141 * redL + 0.11916382 * greenL + 0.95034478 * blueL

        let rD = ViewingConditions.rgbD[0] * (0.401288 * x + 0.650173 * y - 0.051461 * z)
        let gD = ViewingConditions.rgbD[1] * (-0.250268 * x + 1.204414 * y + 0.045854 * z)
        let bD = ViewingConditions.rgbD[2] * (-0.002079 * x + 0.048952 * y + 0.953127 * z)

        let rAF = pow(ViewingConditions.fl * abs(rD) / 100.0, 0.42)
        let gAF = pow(ViewingConditions.fl * abs(gD) / 100.0, 0.42)
        let bAF = pow(ViewingConditions.fl * abs(bD) / 100.0, 0.42)

        let rA = signum(rD) * 400.0 * rAF / (rAF + 27.13)
        let gA = signum(gD) * 400.0 * gAF / (gAF + 27.13)
        let bA = signum(bD) * 400.0 * bAF / (bAF + 27.13)

        let a = (11.0 * rA - 12.0 * gA + bA) / 11.0
        let bCoord = (rA + gA - 2.0 * bA) / 9.0
        let u = (20.0 * rA + 20.0 * gA + 21.0 * bA) / 20.0
        let p2 = (40.0 * rA + 20.0 * gA + bA) / 20.0

        let hue = sanitizeDegrees(atan2(bCoord, a) * 180.0 / Double.pi)
        let j = 100.0 * pow(p2 * ViewingConditions.nbb / ViewingConditions.aw, ViewingConditions.c * ViewingConditions.z)
        let huePrime = hue < 20.14 ? hue + 360.0 : hue
        let eHue = 0.25 * (cos(huePrime * Double.pi / 180.0 + 2.0) + 3.8)
        let p1 = (50000.0 / 13.0) * eHue * ViewingConditions.nc * ViewingConditions.ncb
        let t = p1 * sqrt(a * a + bCoord * bCoord) / (u + 0.305)
        let alpha = pow(t, 0.9) * pow(1.64 - pow(0.29, ViewingConditions.n), 0.73)

        return (
            hue: hue,
            chroma: alpha * sqrt(j / 100.0),
            tone: 116.0 * labF(y / 100.0) - 16.0
        )
    }

    // MARK: - Upstream Tonal.js & Contrast.js Math

    public static let CONTAINER_TINT_DARK: Double = 0.5
    public static let CONTAINER_TINT_LIGHT: Double = 1.0
    public static let CONTAINER_CHROMA_MAX: Double = 48.0
    public static let DARK_TONE_LIMIT: Double = 50.0
    public static let DARK_TONE_FLOOR: Double = 30.0
    public static let DARK_TONE_LIFT: Double = 16.0
    public static let LIGHT_TONE_CEILING: Double = 90.0
    public static let LIGHT_TONE_DROP: Double = 4.0

    /// Mixing formula matching upstream Tonal.js softContainer()
    public static func softContainer(accent: M3Color, card: M3Color, tint: Double) -> M3Color {
        let source = toHct(r: accent.red, g: accent.green, b: accent.blue)
        let surface = toHct(r: card.red, g: card.green, b: card.blue)
        let tone = surface.tone < DARK_TONE_LIMIT ?
            max(DARK_TONE_FLOOR, surface.tone + DARK_TONE_LIFT) :
            min(LIGHT_TONE_CEILING, surface.tone - LIGHT_TONE_DROP)
        let base = fromHct(hue: surface.hue, chroma: surface.chroma, tone: tone)
        let full = fromHct(hue: source.hue, chroma: min(source.chroma, CONTAINER_CHROMA_MAX), tone: tone)
        return mix(base, full, amount: max(0.0, min(1.0, tint)))
    }

    /// Linear relative luminance per WCAG 2.1
    public static func relativeLuminance(_ c: M3Color) -> Double {
        let linear: (Double) -> Double = { v in
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    /// WCAG contrast ratio between two colors (1.0 to 21.0)
    public static func contrastRatio(_ a: M3Color, _ b: M3Color) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Linear interpolation between two RGB colors
    public static func mix(_ c1: M3Color, _ c2: M3Color, amount: Double) -> M3Color {
        let t = max(0.0, min(1.0, amount))
        let r = c1.red * (1.0 - t) + c2.red * t
        let g = c1.green * (1.0 - t) + c2.green * t
        let b = c1.blue * (1.0 - t) + c2.blue * t
        return M3Color.from(r: r, g: g, b: b)
    }

    public static func readableOn(background: M3Color, candidates: [M3Color], target: Double = 4.5) -> M3Color {
        guard let first = candidates.first else { return background }
        var best = first
        for candidate in candidates {
            let current = contrastRatio(candidate, background)
            if current >= target { return candidate }
            if current > contrastRatio(best, background) {
                best = candidate
            }
        }
        return best
    }
}
