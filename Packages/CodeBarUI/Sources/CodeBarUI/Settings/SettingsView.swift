import CodeCore
import SwiftUI

public struct SettingsView: View {
    @State private var codeSets: CodeSetsViewModel
    @State private var abbreviations: AbbreviationsViewModel
    private let isOpenAtLoginEnabled: () -> Bool
    private let setOpenAtLogin: (Bool) -> Bool
    private let isDockIconShown: () -> Bool
    private let setDockIconShown: (Bool) -> Void
    private let onImportCodeSet: (() -> Void)?

    public init(
        codeSets: CodeSetsViewModel,
        abbreviations: AbbreviationsViewModel,
        isOpenAtLoginEnabled: @escaping () -> Bool,
        setOpenAtLogin: @escaping (Bool) -> Bool,
        isDockIconShown: @escaping () -> Bool,
        setDockIconShown: @escaping (Bool) -> Void,
        onImportCodeSet: (() -> Void)? = nil
    ) {
        _codeSets = State(initialValue: codeSets)
        _abbreviations = State(initialValue: abbreviations)
        self.isOpenAtLoginEnabled = isOpenAtLoginEnabled
        self.setOpenAtLogin = setOpenAtLogin
        self.isDockIconShown = isDockIconShown
        self.setDockIconShown = setDockIconShown
        self.onImportCodeSet = onImportCodeSet
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(
                isOpenAtLoginEnabled: isOpenAtLoginEnabled,
                setOpenAtLogin: setOpenAtLogin,
                isDockIconShown: isDockIconShown,
                setDockIconShown: setDockIconShown
            )
            .tabItem { Label("General", systemImage: "gearshape") }

            CodeSetsSettingsView(
                model: codeSets,
                onImport: onImportCodeSet
            )
            .tabItem { Label("Code Sets", systemImage: "cylinder.split.1x2") }

            AbbreviationsSettingsView(model: abbreviations)
                .tabItem { Label("Abbreviations", systemImage: "character.book.closed") }
        }
        .frame(width: Metric.settingsWidth, height: Metric.settingsHeight)
        .task { await codeSets.load() }
    }
}

struct GeneralSettingsView: View {
    let isOpenAtLoginEnabled: () -> Bool
    let setOpenAtLogin: (Bool) -> Bool
    let isDockIconShown: () -> Bool
    let setDockIconShown: (Bool) -> Void

    @State private var opensAtLogin = false
    @State private var showsDockIcon = false

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: Metric.m) {
                    SettingsIconBadge(systemName: "arrow.clockwise.circle.fill", color: .blue)

                    VStack(alignment: .leading, spacing: Metric.xxs) {
                        Text("Open CodeBar at login")
                            .font(.body)
                        Text("Launches automatically on sign-in so keyboard shortcuts remain instantly responsive.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $opensAtLogin)
                        .labelsHidden()
                        .onChange(of: opensAtLogin) { _, enabled in
                            guard setOpenAtLogin(enabled) else {
                                opensAtLogin = isOpenAtLoginEnabled()
                                return
                            }
                        }
                }
                .padding(.vertical, Metric.xxs)
            } header: {
                Text("Startup & Behavior")
            }

            Section {
                HStack(alignment: .center, spacing: Metric.m) {
                    SettingsIconBadge(systemName: "dock.rectangle", color: .indigo)

                    VStack(alignment: .leading, spacing: Metric.xxs) {
                        Text("Show CodeBar in the Dock")
                            .font(.body)
                        Text("When disabled, CodeBar lives exclusively in your menu bar and opens via shortcut.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $showsDockIcon)
                        .labelsHidden()
                        .onChange(of: showsDockIcon) { _, shows in setDockIconShown(shows) }
                }
                .padding(.vertical, Metric.xxs)
            } header: {
                Text("Appearance")
            }

            Section {
                HStack(alignment: .center, spacing: Metric.m) {
                    SettingsIconBadge(systemName: "command", color: .orange)

                    VStack(alignment: .leading, spacing: Metric.xxs) {
                        Text("Open Search Panel")
                            .font(.body)
                        Text("Summon the clinical code search HUD from any application.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    KeycapGroup(symbols: "⌥⌘C")
                }
                .padding(.vertical, Metric.xxs)
            } header: {
                Text("Keyboard Shortcut")
            } footer: {
                Text("Customizable global hotkey support is planned for a future update.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            opensAtLogin = isOpenAtLoginEnabled()
            showsDockIcon = isDockIconShown()
        }
    }
}
