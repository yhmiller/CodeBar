import CodeCore
import SwiftUI

struct CodeSetsSettingsView: View {
    @State var model: CodeSetsViewModel
    @State private var pendingRemoval: CodeSetManifest?

    var body: some View {
        Form {
            if let failure = model.failure {
                Section {
                    Label(failure, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }

            if model.manifests.isEmpty {
                Section {
                    Text("No code sets installed.")
                        .foregroundStyle(.secondary)
                    Text("Use Import Code Set… from the menu bar. Converters for the "
                         + "official releases are in Scripts/.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Section("Installed") {
                    ForEach(model.manifests) { manifest in
                        row(for: manifest)
                    }
                }
                .id(model.preferenceRevision)

                Section {
                    Text("Turning a system off hides it from search without deleting "
                         + "anything. Removing deletes its codes; your pins are kept.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .disabled(model.isWorking)
        .confirmationDialog(
            "Remove \(pendingRemoval?.system.rawValue ?? "") from CodeBar?",
            isPresented: .init(get: { pendingRemoval != nil },
                               set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                guard let system = pendingRemoval?.system else { return }
                pendingRemoval = nil
                Task { await model.remove(system) }
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            if let pendingRemoval {
                Text("\(pendingRemoval.rowCount.formatted()) codes will be deleted. "
                     + "You can import the set again at any time, and your pinned "
                     + "codes are not affected.")
            }
        }
    }

    private func row(for manifest: CodeSetManifest) -> some View {
        HStack(spacing: 12) {
            Toggle(
                isOn: .init(
                    get: { model.isSearchEnabled(manifest.system) },
                    set: { model.setSearchEnabled(manifest.system, $0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(manifest.system.rawValue)
                    Text(subtitle(for: manifest))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Remove") { pendingRemoval = manifest }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
        }
        .padding(.vertical, 2)
    }

    /// Release first: a set a year out of date answers every query confidently,
    /// and the only visible symptom is a retired code.
    private func subtitle(for manifest: CodeSetManifest) -> String {
        let count = "\(manifest.rowCount.formatted()) codes"
        guard let release = manifest.release else {
            return "\(count) · release unknown"
        }
        return "Release \(release) · \(count)"
    }
}
