import SwiftUI

struct WindowPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var regionCapture = RegionFrameCapture.shared

    @State private var windows: [CaptureWindowInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var needsPermission = false

    let onSelect: (CaptureWindowInfo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            if needsPermission {
                permissionBanner
            }

            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Поиск открытых окон…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Повторить") { loadWindows() }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if windows.isEmpty {
                    VStack(spacing: 12) {
                        Text("Нет подходящих окон")
                            .font(.headline)
                        Text("Откройте Safari с игрой (fon.bet) и нажмите «Обновить»")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Обновить") { loadWindows() }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(windows) { window in
                        Button {
                            onSelect(window)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: iconForApp(window.appName))
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(window.appName)
                                        .font(.headline)
                                    if !window.title.isEmpty {
                                        Text(window.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Text("\(window.width)×\(window.height)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }

                                Spacer()

                                if isLikelyGameWindow(window) {
                                    Text("игра")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 440)
        .task { loadWindows() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Выберите окно с игрой")
                    .font(.title2.weight(.semibold))
                Text("Например: Safari с fon.bet — ИИ будет анализировать всё окно")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Обновить") { loadWindows() }
                .buttonStyle(.bordered)
            Button("Отмена") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding()
    }

    private var permissionBanner: some View {
        HStack {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)
            Text("Разрешите «Запись экрана» для списка окон")
                .font(.caption)
            Spacer()
            Button("Настройки") {
                regionCapture.requestScreenRecordingPermission()
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
    }

    private func loadWindows() {
        isLoading = true
        errorMessage = nil

        if !regionCapture.checkScreenRecordingPermission() {
            needsPermission = true
            regionCapture.requestScreenRecordingPermission()
        } else {
            needsPermission = false
        }

        Task {
            do {
                windows = try await WindowCaptureManager.shared.listWindows()
                if windows.isEmpty {
                    errorMessage = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func iconForApp(_ appName: String) -> String {
        let lower = appName.lowercased()
        if lower.contains("safari") { return "safari" }
        if lower.contains("chrome") { return "globe" }
        if lower.contains("firefox") { return "globe" }
        return "macwindow"
    }

    private func isLikelyGameWindow(_ window: CaptureWindowInfo) -> Bool {
        let title = window.title.lowercased()
        return title.contains("fon") || title.contains("dart") || title.contains("игр")
    }
}
