import Testing
import Foundation
@testable import DMSCore

@Suite("Wall-Clock Synchronization Tests")
struct ClockSyncTests {

    @Test("Exact delay to next second boundary with standard 5ms epsilon")
    func testDelayToNextSecond() {
        // Given a timestamp exactly at .750 seconds
        let date1 = Date(timeIntervalSinceReferenceDate: 1000.750)
        let delay1 = ClockSyncMath.delayToNextSecond(from: date1, epsilon: 0.005)
        // Expected delay: (1.0 - 0.750) + 0.005 = 0.255s
        #expect(abs(delay1 - 0.255) < 0.0001)

        // Given a timestamp at top of the second .000
        let date2 = Date(timeIntervalSinceReferenceDate: 1000.000)
        let delay2 = ClockSyncMath.delayToNextSecond(from: date2, epsilon: 0.005)
        // Expected delay: (1.0 - 0.0) + 0.005 = 1.005s
        #expect(abs(delay2 - 1.005) < 0.0001)

        // Given a timestamp at end of the second .999
        let date3 = Date(timeIntervalSinceReferenceDate: 1000.999)
        let delay3 = ClockSyncMath.delayToNextSecond(from: date3, epsilon: 0.005)
        // Expected delay: (1.0 - 0.999) + 0.005 = 0.006s
        #expect(abs(delay3 - 0.006) < 0.0001)

        // Given a timestamp right after the second boundary .005
        let date4 = Date(timeIntervalSinceReferenceDate: 1000.005)
        let delay4 = ClockSyncMath.delayToNextSecond(from: date4, epsilon: 0.005)
        // Expected delay: (1.0 - 0.005) + 0.005 = 1.000s
        #expect(abs(delay4 - 1.000) < 0.0001)
    }

    @Test("Zero drift across successive simulated ticks")
    func testZeroDriftSimulation() {
        var current = Date(timeIntervalSinceReferenceDate: 123456.634)
        for _ in 0..<10 {
            let delay = ClockSyncMath.delayToNextSecond(from: current, epsilon: 0.004)
            current = current.addingTimeInterval(delay)
            let fractional = current.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.0)
            // Each tick lands within 0.004 of the whole second
            #expect(abs(fractional - 0.004) < 0.0001)
        }
    }

    @Test("Floor to integer second")
    func testFloorToSecond() {
        let d = Date(timeIntervalSinceReferenceDate: 98765.432)
        let floored = ClockSyncMath.floorToSecond(d)
        #expect(floored.timeIntervalSinceReferenceDate == 98765.0)
    }
}
