import SwiftUI
import DMSCore

/// Material 3 Process Manager / Activity Monitor modal view.
public struct ProcessListView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var processService = ProcessService.shared
    @State private var searchText: String = ""
    @State private var sortByMemory: Bool
    @State private var selectedPID: Int32? = nil

    let onClose: () -> Void

    public init(sortByMemory: Bool = false, onClose: @escaping () -> Void) {
        self._sortByMemory = State(initialValue: sortByMemory)
        self.onClose = onClose
    }

    private var displayedProcesses: [ProcessInfoItem] {
        var list = processService.processes
        let clean = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !clean.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(clean) || String($0.pid).contains(clean) || $0.user.lowercased().contains(clean)
            }
        }
        if sortByMemory {
            return list.sorted { $0.memoryMB > $1.memoryMB }
        } else {
            return list.sorted { $0.cpuPercent > $1.cpuPercent }
        }
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: sortByMemory ? "memorychip" : "gauge.with.needle.fill")
                    .foregroundColor(Color(hex: p.primary.hex))

                Text(sortByMemory ? "Memory & Services" : "Process Manager")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))

                Spacer()

                // Refresh button
                Button(action: {
                    processService.refresh()
                    TelemetryService.shared.refresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: p.surfaceVariant.hex))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: p.surfaceVariant.hex))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(hex: p.surfaceContainerHigh.hex))

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Telemetry Overview Card
            telemetryOverviewCard(p: p)

            // Filter & Sort Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: p.outline.hex))
                    TextField("Filter processes or PID...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: p.surfaceContainerLow.hex))
                .cornerRadius(10)

                Spacer()

                HStack(spacing: 6) {
                    Button(action: { sortByMemory = false }) {
                        Text("Sort CPU")
                            .font(.system(size: 11, weight: !sortByMemory ? .bold : .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(!sortByMemory ? Color(hex: p.primaryContainer.hex) : Color.clear)
                            .foregroundColor(!sortByMemory ? Color(hex: p.primary.hex) : Color(hex: p.onSurfaceVariant.hex))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: { sortByMemory = true }) {
                        Text("Sort RAM")
                            .font(.system(size: 11, weight: sortByMemory ? .bold : .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(sortByMemory ? Color(hex: p.primaryContainer.hex) : Color.clear)
                            .foregroundColor(sortByMemory ? Color(hex: p.primary.hex) : Color(hex: p.onSurfaceVariant.hex))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: p.surfaceContainerHigh.hex))

            // Table Column Headers
            HStack(spacing: 8) {
                Text("PROCESS")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("PID")
                    .frame(width: 45, alignment: .trailing)
                Text("CPU %")
                    .frame(width: 50, alignment: .trailing)
                Text("RAM (MB)")
                    .frame(width: 60, alignment: .trailing)
                Text("ACTION")
                    .frame(width: 40, alignment: .center)
            }
            .font(.system(size: 9.5, weight: .bold))
            .foregroundColor(Color(hex: p.outline.hex))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(hex: p.surfaceContainerLow.hex))

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Process Rows
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(displayedProcesses.prefix(80)) { proc in
                        HStack(spacing: 8) {
                            Text(proc.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(proc.pid)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: p.outline.hex))
                                .frame(width: 45, alignment: .trailing)

                            Text(String(format: "%.1f%%", proc.cpuPercent))
                                .font(.system(size: 10, weight: proc.cpuPercent > 10.0 ? .bold : .regular, design: .monospaced))
                                .foregroundColor(proc.cpuPercent > 10.0 ? Color(hex: p.error.hex) : Color(hex: p.onSurface.hex))
                                .frame(width: 50, alignment: .trailing)

                            Text(String(format: "%.1f", proc.memoryMB))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                                .frame(width: 60, alignment: .trailing)

                            Button(action: {
                                _ = processService.killProcess(pid: proc.pid)
                                ToastCenter.shared.show(icon: "xmark.circle.fill", message: "Terminated \(proc.name) (\(proc.pid))")
                            }) {
                                Text("End")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(hex: p.error.hex))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: p.errorContainer.hex).opacity(0.4))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 40, alignment: .center)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(proc.pid == selectedPID ? Color(hex: p.primaryContainer.hex).opacity(0.3) : Color.clear)
                        .onTapGesture {
                            selectedPID = proc.pid
                        }
                    }
                }
            }

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Footer
            HStack {
                Text("\(displayedProcesses.count) processes listed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: p.outline.hex))
                Spacer()
                Text("Sorted by \(sortByMemory ? "RAM" : "CPU") descending")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: p.outline.hex))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: p.surfaceContainerHigh.hex))
        }
        .frame(width: 400, height: 350)
        .background(Color(hex: p.surface.hex))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
    }

    @ViewBuilder
    private func telemetryOverviewCard(p: ThemePalette) -> some View {
        let t = TelemetryService.shared.telemetry
        VStack(spacing: 8) {
            if sortByMemory {
                // Memory Overview Card
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: p.outlineVariant.hex).opacity(0.3), lineWidth: 5)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: min(1.0, CGFloat(t.ramPercent) / 100.0))
                            .stroke(
                                t.ramPercent > 85.0 ? Color(hex: p.error.hex) : (t.ramPercent >= 70.0 ? Color(hex: p.tertiary.hex) : Color(hex: p.primary.hex)),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)
                        Image(systemName: "memorychip")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: p.primary.hex))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Memory Utilization")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                            Spacer()
                            Text(String(format: "%.1f GB / %.1f GB (%.0f%%)", t.ramUsedGB, t.ramTotalGB, t.ramPercent))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(t.ramPercent > 85.0 ? Color(hex: p.error.hex) : Color(hex: p.primary.hex))
                        }

                        // Progress gauge
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: p.surfaceContainerHighest.hex))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(
                                        t.ramPercent > 85.0 ? Color(hex: p.error.hex) : (t.ramPercent >= 70.0 ? Color(hex: p.tertiary.hex) : Color(hex: p.primary.hex))
                                    )
                                    .frame(width: max(6, barGeo.size.width * CGFloat(min(1.0, t.ramPercent / 100.0))), height: 6)
                            }
                        }
                        .frame(height: 6)

                        HStack(spacing: 12) {
                            Text("Used: \(String(format: "%.1f GB", t.ramUsedGB))")
                            Text("•")
                            Text("Free: \(String(format: "%.1f GB", max(0.0, t.ramTotalGB - t.ramUsedGB)))")
                            Spacer()
                            Text("Active Services: \(displayedProcesses.count)")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: p.surfaceContainerHigh.hex))
                .cornerRadius(14)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            } else {
                // CPU Overview Card
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: p.outlineVariant.hex).opacity(0.3), lineWidth: 5)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: min(1.0, CGFloat(t.cpuPercent) / 100.0))
                            .stroke(
                                t.cpuPercent > 85.0 ? Color(hex: p.error.hex) : (t.cpuPercent >= 70.0 ? Color(hex: p.tertiary.hex) : Color(hex: p.primary.hex)),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)
                        Image(systemName: "cpu")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: p.primary.hex))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("CPU Aggregate Load")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                            Spacer()
                            Text(String(format: "%.1f%% Load", t.cpuPercent))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(t.cpuPercent > 85.0 ? Color(hex: p.error.hex) : Color(hex: p.primary.hex))
                        }

                        // Progress gauge
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: p.surfaceContainerHighest.hex))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(
                                        t.cpuPercent > 85.0 ? Color(hex: p.error.hex) : (t.cpuPercent >= 70.0 ? Color(hex: p.tertiary.hex) : Color(hex: p.primary.hex))
                                    )
                                    .frame(width: max(6, barGeo.size.width * CGFloat(min(1.0, t.cpuPercent / 100.0))), height: 6)
                            }
                        }
                        .frame(height: 6)

                        HStack(spacing: 12) {
                            Text("Aggregate: \(String(format: "%.1f%%", t.cpuPercent))")
                            Text("•")
                            Text("Active Processes: \(displayedProcesses.count)")
                            Spacer()
                            Text(t.cpuPercent > 85.0 ? "Heavy Load" : (t.cpuPercent > 50.0 ? "Moderate" : "Normal Load"))
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: p.surfaceContainerHigh.hex))
                .cornerRadius(14)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
}
