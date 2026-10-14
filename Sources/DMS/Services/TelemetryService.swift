import Foundation
import Observation
import Darwin
import DMSCore

/// Hardware telemetry metrics for CPU, RAM, and Battery.
@MainActor
@Observable
public final class TelemetryService {
    public static let shared = TelemetryService()

    public private(set) var telemetry = SystemTelemetry()

    @ObservationIgnored private var previousCpuInfo: processor_info_array_t?
    @ObservationIgnored private var previousCpuInfoCount: mach_msg_type_number_t = 0
    @ObservationIgnored private var timer: Timer?

    private init() {
        refresh()
        startTimer()
    }

    public func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() {
        let cpu = readCPUUsage()
        let ram = readRAMUsage()
        let battery = BatteryService.shared.status

        telemetry = SystemTelemetry(
            cpuPercent: cpu,
            ramPercent: ram.percent,
            ramUsedGB: ram.usedGB,
            ramTotalGB: ram.totalGB,
            batteryPercent: battery?.capacity,
            isCharging: battery?.isCharging ?? false,
            timeRemainingMinutes: nil
        )
    }

    private func readCPUUsage() -> Double {
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo = processorInfo else {
            return 0.0
        }

        var totalUsage: Double = 0.0

        if let prevInfo = previousCpuInfo {
            for i in 0..<Int(processorCount) {
                let offset = Int(CPU_STATE_MAX) * i
                let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)] - prevInfo[offset + Int(CPU_STATE_USER)])
                let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)] - prevInfo[offset + Int(CPU_STATE_SYSTEM)])
                let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)] - prevInfo[offset + Int(CPU_STATE_NICE)])
                let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)] - prevInfo[offset + Int(CPU_STATE_IDLE)])

                let total = user + system + nice + idle
                if total > 0 {
                    totalUsage += (user + system + nice) / total
                }
            }
            totalUsage = (totalUsage / Double(processorCount)) * 100.0
        }

        if let prev = previousCpuInfo {
            let prevSize = vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: prev)), prevSize)
        }

        previousCpuInfo = cpuInfo
        previousCpuInfoCount = processorInfoCount

        return min(100.0, max(0.0, totalUsage))
    }

    private func readRAMUsage() -> (percent: Double, usedGB: Double, totalGB: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let totalGB = totalBytes / 1_073_741_824.0

        guard kerr == KERN_SUCCESS else {
            return (0.0, 0.0, totalGB)
        }

        let pageSize = Double(getpagesize())
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let usedBytes = active + wired + compressed
        let usedGB = usedBytes / 1_073_741_824.0
        let percent = min(100.0, max(0.0, (usedBytes / totalBytes) * 100.0))

        return (percent, usedGB, totalGB)
    }

    isolated deinit {
        if let prev = previousCpuInfo {
            let prevSize = vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: prev)), prevSize)
        }
    }
}
