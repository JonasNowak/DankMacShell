import SwiftUI
import DMSCore

/// Material 3 Process Manager / Activity Monitor modal view.
public struct ProcessListView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var processService = ProcessService.shared
    @State private var searchText: String = ""
    @State private var sortByMemory: Bool = false
    @State private var selectedPID: Int32? = nil

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
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
                Image(systemName: "gauge.with.needle.fill")
                    .foregroundColor(Color(hex: p.primary.hex))

                Text("Process Manager")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))

                Spacer()

                // Refresh button
                Button(action: { processService.refresh() }) {
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
            HStack(spacing: 12) {
                Text("PROCESS")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("PID")
                    .frame(width: 60, alignment: .trailing)
                Text("CPU %")
                    .frame(width: 70, alignment: .trailing)
                Text("RAM (MB)")
                    .frame(width: 80, alignment: .trailing)
                Text("ACTION")
                    .frame(width: 60, alignment: .center)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color(hex: p.outline.hex))
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(Color(hex: p.surfaceContainerLow.hex))

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Process Rows
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(displayedProcesses.prefix(80)) { proc in
                        HStack(spacing: 12) {
                            Text(proc.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(proc.pid)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(hex: p.outline.hex))
                                .frame(width: 60, alignment: .trailing)

                            Text(String(format: "%.1f%%", proc.cpuPercent))
                                .font(.system(size: 12, weight: proc.cpuPercent > 10.0 ? .bold : .regular, design: .monospaced))
                                .foregroundColor(proc.cpuPercent > 10.0 ? Color(hex: p.error.hex) : Color(hex: p.onSurface.hex))
                                .frame(width: 70, alignment: .trailing)

                            Text(String(format: "%.1f", proc.memoryMB))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                                .frame(width: 80, alignment: .trailing)

                            Button(action: {
                                _ = processService.killProcess(pid: proc.pid)
                                ToastCenter.shared.show(icon: "xmark.circle.fill", message: "Terminated \(proc.name) (\(proc.pid))")
                            }) {
                                Text("End")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: p.error.hex))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: p.errorContainer.hex).opacity(0.4))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 60, alignment: .center)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: p.outline.hex))
                Spacer()
                Text("Sorted by \(sortByMemory ? "RAM" : "CPU") descending")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: p.outline.hex))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color(hex: p.surfaceContainerHigh.hex))
        }
        .frame(width: 580, height: 460)
        .background(Color(hex: p.surface.hex))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 26, x: 0, y: 12)
    }
}
