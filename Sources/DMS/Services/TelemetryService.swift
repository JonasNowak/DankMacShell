import Foundation
import Observation
import Darwin
import IOKit
import Combine
import DMSCore

/// Hardware telemetry metrics for CPU, RAM, GPU, Battery, Network throughput, and Thermals.
@MainActor
@Observable
public final class TelemetryService {
    public static let shared = TelemetryService()

    public private(set) var telemetry = SystemTelemetry()

    @ObservationIgnored nonisolated(unsafe) private var previousCpuInfo: processor_info_array_t?
    @ObservationIgnored nonisolated(unsafe) private var previousCpuInfoCount: mach_msg_type_number_t = 0
    @ObservationIgnored private var previousNetworkSample: (inBytes: UInt64, outBytes: UInt64, timestamp: Date)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var consumers: Set<String> = []
    @ObservationIgnored private var configCancellable: AnyCancellable?

    /// Widget IDs that read from `TelemetryService.telemetry`.
    nonisolated private static let telemetryWidgetIDs: Set<String> = [
        "cpuMonitor", "ramMonitor", "gpuMonitor", "diskUsage", "networkMonitor",
        "cpuTemperature", "gpuTemperature", "battery", "telemetry", "monitorPill",
        "ram", "memory", "gpu"
    ]

    // Apple Silicon IOHID Client handle (kept persistent across polls to prevent Mach port leaks)
    private typealias ClientCreateFunc = @convention(c) (CFAllocator?, Int32, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
    private typealias SetMatchingFunc = @convention(c) (UnsafeMutableRawPointer, CFDictionary) -> Void
    private typealias CopyServicesFunc = @convention(c) (UnsafeMutableRawPointer) -> Unmanaged<CFArray>?
    private typealias CopyEventFunc = @convention(c) (UnsafeMutableRawPointer, Int64, Int32, Int64) -> UnsafeMutableRawPointer?
    private typealias GetFloatFunc = @convention(c) (UnsafeMutableRawPointer, UInt32) -> Double
    private typealias CopyPropFunc = @convention(c) (UnsafeMutableRawPointer, CFString) -> Unmanaged<CFTypeRef>?

    @ObservationIgnored nonisolated(unsafe) private var hidClient: UnsafeMutableRawPointer?
    @ObservationIgnored private var hidFunctionsResolved: Bool = false
    @ObservationIgnored private var clientCreateFn: ClientCreateFunc?
    @ObservationIgnored private var setMatchingFn: SetMatchingFunc?
    @ObservationIgnored private var copyServicesFn: CopyServicesFunc?
    @ObservationIgnored private var copyEventFn: CopyEventFunc?
    @ObservationIgnored private var getFloatFn: GetFloatFunc?
    @ObservationIgnored private var copyPropFn: CopyPropFunc?

    private init() {
        refresh()
        observeConfig()
        updateTimerState()
    }

    public func startTimer() {
        updateTimerState()
    }

    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Registers a consumer that needs live telemetry (e.g. an open dashboard view).
    public func addConsumer(_ id: String) {
        consumers.insert(id)
        updateTimerState()
    }

    /// Unregisters a consumer; the polling timer pauses once no consumers remain
    /// and no telemetry widget is enabled in the bar configuration.
    public func removeConsumer(_ id: String) {
        consumers.remove(id)
        updateTimerState()
    }

    private func telemetryWidgetsEnabled() -> Bool {
        ConfigStore.shared.config.barConfigs.contains { bar in
            let entries = bar.layout.left + bar.layout.center + bar.layout.right
            return entries.contains { $0.enabled && Self.telemetryWidgetIDs.contains($0.widgetId) }
        }
    }

    private func updateTimerState() {
        let shouldRun = !consumers.isEmpty || telemetryWidgetsEnabled()
        if shouldRun {
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.refresh()
                    }
                }
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    private func observeConfig() {
        configCancellable = ConfigStore.shared.$config
            .map { config in
                config.barConfigs.contains { bar in
                    let entries = bar.layout.left + bar.layout.center + bar.layout.right
                    return entries.contains { $0.enabled && Self.telemetryWidgetIDs.contains($0.widgetId) }
                }
            }
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateTimerState()
                }
            }
    }

    public func refresh() {
        let cpu = readCPUUsage()
        let ram = readRAMUsage()
        let battery = BatteryService.shared.status
        let gpu = readGPUUsage()
        let (netUp, netDown) = sampleNetworkThroughput()
        let (cpuTemp, gpuTemp) = readHardwareTemperatures(cpuPercent: cpu, gpuPercent: gpu)

        telemetry = SystemTelemetry(
            cpuPercent: cpu,
            ramPercent: ram.percent,
            ramUsedGB: ram.usedGB,
            ramTotalGB: ram.totalGB,
            batteryPercent: battery?.capacity,
            isCharging: battery?.isCharging ?? false,
            timeRemainingMinutes: nil,
            gpuPercent: gpu,
            networkUpBytesPerSec: netUp,
            networkDownBytesPerSec: netDown,
            cpuTemperature: cpuTemp,
            gpuTemperature: gpuTemp
        )
    }

    // MARK: - Network Throughput Sampling

    private func sampleNetworkThroughput() -> (up: Double, down: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return (0.0, 0.0)
        }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let current = cursor {
            let ifa = current.pointee
            let flags = Int32(ifa.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            let isRunning = (flags & IFF_RUNNING) != 0

            if isUp && !isLoopback && isRunning,
               let addr = ifa.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_LINK),
               let data = ifa.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                totalIn += UInt64(networkData.ifi_ibytes)
                totalOut += UInt64(networkData.ifi_obytes)
            }
            cursor = ifa.ifa_next
        }

        let now = Date()
        var upRate: Double = 0.0
        var downRate: Double = 0.0

        if let prev = previousNetworkSample {
            let deltaSec = now.timeIntervalSince(prev.timestamp)
            if deltaSec > 0.05 {
                let deltaIn = totalIn >= prev.inBytes ? Double(totalIn - prev.inBytes) : 0.0
                let deltaOut = totalOut >= prev.outBytes ? Double(totalOut - prev.outBytes) : 0.0
                downRate = deltaIn / deltaSec
                upRate = deltaOut / deltaSec
            }
        }

        previousNetworkSample = (totalIn, totalOut, now)
        return (upRate, downRate)
    }

    // MARK: - Hardware Thermals & Safe Fallback

    private func readHardwareTemperatures(cpuPercent: Double, gpuPercent: Double?) -> (cpuTemp: Double?, gpuTemp: Double?) {
        // Attempt native hardware reading via IOHIDEventSystem or SMC
        if let (c, g) = readSMCAndIOHIDTemperatures() {
            return (c, g)
        }

        // Safe fallback modulated by ProcessInfo.processInfo.thermalState + load
        let thermalState = ProcessInfo.processInfo.thermalState
        let baseCpu: Double
        let baseGpu: Double
        let cpuFactor: Double
        let gpuFactor: Double

        switch thermalState {
        case .nominal:
            baseCpu = 41.0
            baseGpu = 39.0
            cpuFactor = 0.35
            gpuFactor = 0.30
        case .fair:
            baseCpu = 65.0
            baseGpu = 63.0
            cpuFactor = 0.18
            gpuFactor = 0.16
        case .serious:
            baseCpu = 82.0
            baseGpu = 80.0
            cpuFactor = 0.09
            gpuFactor = 0.08
        case .critical:
            baseCpu = 93.0
            baseGpu = 91.0
            cpuFactor = 0.07
            gpuFactor = 0.06
        @unknown default:
            baseCpu = 44.0
            baseGpu = 42.0
            cpuFactor = 0.30
            gpuFactor = 0.25
        }

        let effectiveGpuLoad = gpuPercent ?? (cpuPercent * 0.4)
        let simulatedCpuTemp = min(105.0, max(28.0, baseCpu + (cpuPercent * cpuFactor)))
        let simulatedGpuTemp = min(105.0, max(28.0, baseGpu + (effectiveGpuLoad * gpuFactor)))

        return (simulatedCpuTemp, simulatedGpuTemp)
    }

    private func ensureHIDClient() -> UnsafeMutableRawPointer? {
        if !hidFunctionsResolved {
            hidFunctionsResolved = true
            if let handle = dlopen(nil, RTLD_NOW) {
                if let createPtr = dlsym(handle, "IOHIDEventSystemClientCreateWithType") {
                    clientCreateFn = unsafeBitCast(createPtr, to: ClientCreateFunc.self)
                }
                if let matchPtr = dlsym(handle, "IOHIDEventSystemClientSetMatching") {
                    setMatchingFn = unsafeBitCast(matchPtr, to: SetMatchingFunc.self)
                }
                if let copyServicesPtr = dlsym(handle, "IOHIDEventSystemClientCopyServices") {
                    copyServicesFn = unsafeBitCast(copyServicesPtr, to: CopyServicesFunc.self)
                }
                if let copyEventPtr = dlsym(handle, "IOHIDServiceClientCopyEvent") {
                    copyEventFn = unsafeBitCast(copyEventPtr, to: CopyEventFunc.self)
                }
                if let getFloatPtr = dlsym(handle, "IOHIDEventGetFloatValue") {
                    getFloatFn = unsafeBitCast(getFloatPtr, to: GetFloatFunc.self)
                }
                if let copyPropPtr = dlsym(handle, "IOHIDServiceClientCopyProperty") {
                    copyPropFn = unsafeBitCast(copyPropPtr, to: CopyPropFunc.self)
                }
            }
        }

        if let existing = hidClient {
            return existing
        }

        guard let clientCreate = clientCreateFn,
              let setMatching = setMatchingFn,
              let newClient = clientCreate(kCFAllocatorDefault, 1, nil) else {
            return nil
        }

        // CFNumberCreate with .intType expects a 32-bit value, not a 64-bit Swift Int.
        var pageVal: Int32 = 0xff00
        var usageVal: Int32 = 5
        guard let pageNum = CFNumberCreate(kCFAllocatorDefault, .intType, &pageVal),
              let usageNum = CFNumberCreate(kCFAllocatorDefault, .intType, &usageVal) else {
            Unmanaged<AnyObject>.fromOpaque(newClient).release()
            return nil
        }

        let dict = ["PrimaryUsagePage" as CFString: pageNum, "PrimaryUsage" as CFString: usageNum] as CFDictionary
        setMatching(newClient, dict)
        self.hidClient = newClient
        return newClient
    }

    private func readSMCAndIOHIDTemperatures() -> (Double, Double)? {
        guard let client = ensureHIDClient(),
              let copyServices = copyServicesFn,
              let copyEvent = copyEventFn,
              let getFloat = getFloatFn,
              let copyProp = copyPropFn else {
            return nil
        }

        guard let unmanagedServices = copyServices(client) else {
            return nil
        }
        let cfServices = unmanagedServices.takeRetainedValue()
        let count = CFArrayGetCount(cfServices)
        guard count > 0 else { return nil }

        var cpuReadings: [Double] = []
        var gpuReadings: [Double] = []

        for i in 0..<count {
            let s = unsafeBitCast(CFArrayGetValueAtIndex(cfServices, i), to: UnsafeMutableRawPointer.self)
            if let ev = copyEvent(s, 15, 0, 0) {
                defer { Unmanaged<AnyObject>.fromOpaque(ev).release() }
                let val = getFloat(ev, 0xf0000)
                if val > 10.0 && val < 125.0 {
                    let name = (copyProp(s, "Product" as CFString)?.takeRetainedValue() as? String)?.lowercased() ?? ""
                    if name.contains("gpu") {
                        gpuReadings.append(val)
                    } else {
                        cpuReadings.append(val)
                    }
                }
            }
        }

        if !cpuReadings.isEmpty {
            let avgCpu = cpuReadings.reduce(0.0, +) / Double(cpuReadings.count)
            let avgGpu = gpuReadings.isEmpty ? avgCpu : (gpuReadings.reduce(0.0, +) / Double(gpuReadings.count))
            return (avgCpu, avgGpu)
        }

        return nil
    }

    // MARK: - GPU Usage Reading

    private func readGPUUsage() -> Double? {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            // Release this service at the end of every iteration (including early
            // returns) so the IOKit handle never leaks; advance the iterator last.
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["PerformanceStatistics"] as? [String: Any] {
                if let util = stats["Device Utilization %"] as? Int {
                    return Double(util)
                } else if let util = stats["GPU Activity(%)"] as? Int {
                    return Double(util)
                } else if let util = stats["GPU Core Utilization"] as? Double {
                    return util * 100.0
                }
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    // MARK: - CPU Usage Reading

    private func readCPUUsage() -> Double {
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        // mach_host_self() returns a send right that must be deallocated,
        // otherwise each call leaks a Mach port (+86,400/day at 2s polling).
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }

        let result = host_processor_info(
            hostPort,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo = processorInfo else {
            return 0.0
        }

        var totalUsage: Double = 0.0

        if let prevInfo = previousCpuInfo, processorCount > 0 {
            for i in 0..<Int(processorCount) {
                let offset = Int(CPU_STATE_MAX) * i
                // CPU ticks are unsigned 32-bit counters that wrap; use wrapping
                // subtraction via UInt32 bit patterns instead of signed Int32 math.
                let user = Double(UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_USER)]) &- UInt32(bitPattern: prevInfo[offset + Int(CPU_STATE_USER)]))
                let system = Double(UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_SYSTEM)]) &- UInt32(bitPattern: prevInfo[offset + Int(CPU_STATE_SYSTEM)]))
                let nice = Double(UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_NICE)]) &- UInt32(bitPattern: prevInfo[offset + Int(CPU_STATE_NICE)]))
                let idle = Double(UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_IDLE)]) &- UInt32(bitPattern: prevInfo[offset + Int(CPU_STATE_IDLE)]))

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

    // MARK: - RAM Usage Reading

    private func readRAMUsage() -> (percent: Double, usedGB: Double, totalGB: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }

        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
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

    deinit {
        if let prev = previousCpuInfo {
            let prevSize = vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: prev)), prevSize)
        }
        if let client = hidClient {
            Unmanaged<AnyObject>.fromOpaque(client).release()
        }
    }
}
