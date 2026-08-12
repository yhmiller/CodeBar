import CodeCore
import SwiftUI

private let SETTINGS_WIDTH: CGFloat = 540
private let SETTINGS_HEIGHT: CGFloat = 380

/// The app's first real window, and the shell later panes plug into.
///
/// See docs/ARCHITECTURE.md §11 — CodeBar is growing into a full app that keeps
/// the menu bar panel, and this is step one of that.
public struct SettingsView: View {
    @State private var codeSets: CodeSetsViewModel
    private let isOpenAtLoginEnabled: () -> Bool
    private let setOpenAtLogin: (Bool) -> Bool
    private let isDockIconShown: () -> Bool
    private let setDockIconShown: (Bool) -> Void

    public init(
        codeSets: CodeSetsViewModel,
        isOpenAtLoginEnabled: @escaping () -> Bool,
        setOpenAtLogin: @escaping (Bool) -> Bool,
        isDockIconShown: @escaping () -> Bool,
        setDockIconShown: @escaping (Bool) -> Void
    ) {
        _codeSets = State(initialValue: codeSets)
        self.isOpenAtLoginEnabled = isOpenAtLoginEnabled
        self.setOpenAtLogin = setOpenAtLogin
        self.isDockIconShown = isDockIconShown
        self.setDockIconShown = setDockIconShown
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

            CodeSetsSettingsView(model: codeSets)
                .tabItem { Label("Code Sets", systemImage: "list.bullet.rectangle") }
        }
        .frame(width: SETTINGS_WIDTH, height: SETTINGS_HEIGHT)
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
                Toggle("Open CodeBar at login", isOn: $opensAtLogin)
                    .onChange(of: opensAtLogin) { _, enabled in
                        // Revert if macOS refused, rather than showing a state
                        // the system does not actually have.
                        guard setOpenAtLogin(enabled) else {
                            opensAtLogin = isOpenAtLoginEnabled()
                            return
                        }
                    }
                Text("A menu bar app that is not running looks broken: the shortcut "
                     + "silently does nothing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Toggle("Show CodeBar in the Dock", isOn: $showsDockIcon)
                    .onChange(of: showsDockIcon) { _, shows in setDockIconShown(shows) }
                Text("Off keeps CodeBar in the menu bar only, reachable by ⌥⌘C and "
                     + "the menu bar icon. On, opening CodeBar opens the browse window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcut") {
                LabeledContent("Open search", value: "⌥⌘C")
                Text("Fixed for now. Configurable shortcuts are planned.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            opensAtLogin = isOpenAtLoginEnabled()
            showsDockIcon = isDockIconShown()
        }
    }
}
