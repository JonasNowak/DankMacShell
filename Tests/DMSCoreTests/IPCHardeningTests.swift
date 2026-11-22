import Testing
import Foundation
@testable import DMSCore

@Suite("IPC & Media Hardening — CappedBackoffPolicy")
struct IPCHardeningTests {

    @Test("nextDelay() walks the schedule in order")
    func backoffProgression() {
        var policy = CappedBackoffPolicy(schedule: [0.1, 0.2, 0.4])
        #expect(policy.stepIndex == 0)
        #expect(policy.nextDelay() == 0.1)
        #expect(policy.stepIndex == 1)
        #expect(policy.nextDelay() == 0.2)
        #expect(policy.stepIndex == 2)
        #expect(policy.nextDelay() == 0.4)
    }

    @Test("nextDelay() clamps at the maximum delay")
    func backoffClampsAtMax() {
        var policy = CappedBackoffPolicy(schedule: [1.0, 2.0, 4.0])
        #expect(policy.nextDelay() == 1.0)
        #expect(policy.nextDelay() == 2.0)
        #expect(policy.nextDelay() == 4.0)
        #expect(policy.nextDelay() == 4.0)
        #expect(policy.nextDelay() == 4.0)
        #expect(policy.stepIndex == 2)
    }

    @Test("reset() returns to the first step")
    func backoffReset() {
        var policy = CappedBackoffPolicy(schedule: [1.0, 2.0, 4.0])
        _ = policy.nextDelay()
        _ = policy.nextDelay()
        #expect(policy.stepIndex == 2)
        policy.reset()
        #expect(policy.stepIndex == 0)
        #expect(policy.nextDelay() == 1.0)
    }

    @Test("resetIfHealthy(uptime:) only resets at or above healthyResetSeconds")
    func backoffResetIfHealthy() {
        var policy = CappedBackoffPolicy(schedule: [1.0, 2.0, 4.0], healthyResetSeconds: 30.0)
        _ = policy.nextDelay()
        _ = policy.nextDelay()
        #expect(policy.stepIndex == 2)

        policy.resetIfHealthy(uptime: 10.0)
        #expect(policy.stepIndex == 2)
        policy.resetIfHealthy(uptime: 29.999)
        #expect(policy.stepIndex == 2)

        policy.resetIfHealthy(uptime: 30.0)
        #expect(policy.stepIndex == 0)
        #expect(policy.nextDelay() == 1.0)
    }

    @Test("resetIfHealthy(uptime:) with default threshold never auto-resets")
    func backoffResetIfHealthyDefaultThreshold() {
        var policy = CappedBackoffPolicy(schedule: [0.5, 1.0])
        _ = policy.nextDelay()
        #expect(policy.stepIndex == 1)
        policy.resetIfHealthy(uptime: 3600.0)
        #expect(policy.stepIndex == 1)
    }

    @Test("init clamps an out-of-range stepIndex into schedule.indices")
    func initClampsStepIndex() {
        let high = CappedBackoffPolicy(schedule: [1.0, 2.0], stepIndex: 99)
        #expect(high.stepIndex == 1)
        let negative = CappedBackoffPolicy(schedule: [1.0, 2.0], stepIndex: -5)
        #expect(negative.stepIndex == 0)
        var clamped = high
        #expect(clamped.nextDelay() == 2.0)
        #expect(clamped.nextDelay() == 2.0)
    }

    @Test("value semantics: copies do not share stepIndex")
    func backoffValueSemantics() {
        var a = CappedBackoffPolicy.mediaBridge
        let b = a
        #expect(a == b)
        #expect(a.nextDelay() == 1.0)
        #expect(a.stepIndex == 1)
        #expect(b.stepIndex == 0)
        #expect(a != b)
    }

    @Test(".ipcAccept preset: 10ms -> 250ms cap, resets on success")
    func ipcAcceptPreset() {
        var policy = CappedBackoffPolicy.ipcAccept
        #expect(policy.schedule == [0.01, 0.025, 0.05, 0.1, 0.25])
        #expect(policy.nextDelay() == 0.01)
        #expect(policy.nextDelay() == 0.025)
        #expect(policy.nextDelay() == 0.05)
        #expect(policy.nextDelay() == 0.1)
        #expect(policy.nextDelay() == 0.25)
        #expect(policy.nextDelay() == 0.25)
        #expect(policy.nextDelay() == 0.25)
        #expect(policy.stepIndex == 4)
        policy.reset()
        #expect(policy.stepIndex == 0)
        #expect(policy.nextDelay() == 0.01)
    }

    @Test(".mediaBridge preset: 1s -> 30s cap with 30s healthy reset")
    func mediaBridgePreset() {
        var policy = CappedBackoffPolicy.mediaBridge
        #expect(policy.schedule == [1.0, 2.0, 4.0, 8.0, 15.0, 30.0])
        #expect(policy.healthyResetSeconds == 30.0)
        #expect(policy.nextDelay() == 1.0)
        #expect(policy.nextDelay() == 2.0)
        #expect(policy.nextDelay() == 4.0)
        #expect(policy.nextDelay() == 8.0)
        #expect(policy.nextDelay() == 15.0)
        #expect(policy.nextDelay() == 30.0)
        #expect(policy.nextDelay() == 30.0)
        #expect(policy.stepIndex == 5)

        // Short-lived crash-loop: uptime below 30s keeps the backoff at the cap.
        policy.resetIfHealthy(uptime: 5.0)
        #expect(policy.stepIndex == 5)
        #expect(policy.nextDelay() == 30.0)

        // Healthy run (>= 30s uptime) resets to the bottom of the schedule.
        policy.resetIfHealthy(uptime: 45.0)
        #expect(policy.stepIndex == 0)
        #expect(policy.nextDelay() == 1.0)
    }
}
