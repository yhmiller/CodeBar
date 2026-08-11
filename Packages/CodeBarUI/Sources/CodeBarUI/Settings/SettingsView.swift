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

    public init(
        codeSets: CodeSetsViewModel,
        isOpenAtLoginEnabled: @escaping () -> Bool,
        setOpenAtLogin: @escaping (Bool) -> Bool
    ) {
        _codeSets = State(initialValue: codeSets)
        self.isOpenAtLoginEnabled = isOpenAtLoginEnabled
        self.setOpenAtLogin = setOpenAtLogin
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(
                isOpenAtLoginEnabled: isOpenAtLoginEnabled,
                setOpenAtLogin: setOpenAtLogin
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

    @State private var opensAtLogin = false

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

            Section("Shortcut") {
                LabeledContent("Open search", value: "⌥⌘C")
                Text("Fixed for now. Making it configurable is tracked in the roadmap.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { opensAtLogin = isOpenAtLoginEnabled() }
    }
}
