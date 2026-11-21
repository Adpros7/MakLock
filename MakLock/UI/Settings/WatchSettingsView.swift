import SwiftUI

/// Watch settings tab: Apple Watch proximity unlock with pairing and sensitivity.
struct WatchSettingsView: View {
    @ObservedObject private var watchService = WatchProximityService.shared
    @State private var settings = Defaults.shared.appSettings
    @State private var sensitivity: Double = {
        let rssi = Double(Defaults.shared.appSettings.watchRssiThreshold)
        return ((rssi + 90) / 40.0) * 100
    }()

    var body: some View {
        Form {
            // Bluetooth status
            Section {
                bluetoothStatusRow

                if watchService.bluetoothState == .poweredOn
                    || watchService.bluetoothState == .unknown
                {
                    Toggle("Use Apple Watch to unlock", isOn: $settings.useWatchUnlock)
                        .onChange(of: settings.useWatchUnlock) { enabled in
                            Defaults.shared.appSettings = settings
                            if enabled {
                                watchService.startScanning()
                            } else {
                                watchService.stopScanning()
                            }
                        }
                }
            }

            if settings.useWatchUnlock && watchService.bluetoothState == .poweredOn {
                Section("Paired Watch") {
                    if let watchID = watchService.pairedWatchIdentifier {
                        HStack {
                            Image(systemName: "applewatch")
                                .font(.system(size: 24))
                                .foregroundColor(
                                    watchService.isWatchInRange
                                        ? MakLockColors.success : MakLockColors.textSecondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apple Watch")
                                    .font(MakLockTypography.body)
                                Text(watchService.isWatchInRange ? "In range" : "Out of range")
                                    .font(MakLockTypography.caption)
                                    .foregroundColor(
                                        watchService.isWatchInRange
                                            ? MakLockColors.success : .secondary)
                            }

                            Spacer()

                            Button("Unpair") {
                                watchService.unpair()
                                settings.useWatchUnlock = false
                                Defaults.shared.appSettings = settings
                            }
                            .foregroundColor(MakLockColors.error)
                        }
                        .padding(.vertical, 4)

                        // UUID copyable via context menu (NOT .textSelection — causes layout loop in TabView)
                        Text(watchID.uuidString)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .contextMenu {
                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(
                                        watchID.uuidString, forType: .string)
                                }
                            }
                    } else {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching for Apple Watch...")
                                .font(MakLockTypography.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)

                        Text("Make sure your Apple Watch is unlocked, on your wrist, and nearby.")
                            .font(MakLockTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }

            }
            Section("Range Lock") {
                Toggle(
                    "Lock protected apps when Watch leaves range",
                    isOn: $settings.lockWhenWatchLeavesRange
                )
                .onChange(of: settings.lockWhenWatchLeavesRange) { _ in
                    Defaults.shared.appSettings = settings
                }

                Text(
                    "Turn on Apple Watch unlock to activate Range Lock. MakLock waits for three weak readings or 15 seconds without a signal; Bluetooth reconnects alone never lock your apps."
                )
                .font(MakLockTypography.caption)
                .foregroundColor(.secondary)
            }
            Section("Lock Distance") {
                HStack {
                    Text("Range:")
                    Slider(value: $sensitivity, in: 0...100, step: 10)
                        .onChange(of: sensitivity) { value in
                            let rssi = Int(-90 + (value / 100.0) * 40)
                            watchService.rssiThreshold = rssi
                            settings.watchRssiThreshold = rssi
                            Defaults.shared.appSettings = settings
                        }
                    Text(sensitivityLabel)
                        .frame(width: 50, alignment: .trailing)
                        .font(MakLockTypography.caption)
                        .monospacedDigit()
                }

                Text("Far allows more distance before locking. Close locks sooner.")
                    .font(MakLockTypography.caption)
                    .foregroundColor(.secondary)
            }

            Section("How it works") {
                Text(
                    "When your Apple Watch is nearby, MakLock can automatically unlock protected apps without requiring Touch ID or a password. Enable Range Lock to lock protected apps after a sustained Watch range loss."
                )
                .font(MakLockTypography.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Bluetooth Status

    @ViewBuilder
    private var bluetoothStatusRow: some View {
        switch watchService.bluetoothState {
        case .poweredOn:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(MakLockColors.success)
                Text("Bluetooth is on")
                    .font(MakLockTypography.body)
            }

        case .poweredOff:
            HStack(spacing: 8) {
                Image(systemName: "bluetooth")
                    .foregroundColor(MakLockColors.error)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluetooth is off")
                        .font(MakLockTypography.body)
                    Text("Turn on Bluetooth in System Settings to use Apple Watch unlock.")
                        .font(MakLockTypography.caption)
                        .foregroundColor(.secondary)
                }
            }

        case .unauthorized:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(MakLockColors.locked)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluetooth Permission Required")
                        .font(MakLockTypography.body)
                    Text(
                        "MakLock needs Bluetooth access to detect your Apple Watch. Grant permission in System Settings → Privacy & Security → Bluetooth."
                    )
                    .font(MakLockTypography.caption)
                    .foregroundColor(.secondary)
                }
            }

        case .unsupported:
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(MakLockColors.error)
                Text("Bluetooth is not supported on this Mac")
                    .font(MakLockTypography.body)
            }

        case .unknown:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking Bluetooth status...")
                    .font(MakLockTypography.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var sensitivityLabel: String {
        switch sensitivity {
        case 0..<30: return "Far"
        case 30..<70: return "Medium"
        default: return "Close"
        }
    }
}
