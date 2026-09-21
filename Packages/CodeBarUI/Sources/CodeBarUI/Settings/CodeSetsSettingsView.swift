import CodeCore
import SwiftUI

struct CodeSetsSettingsView: View {
    @State var model: CodeSetsViewModel
    let onImport: (() -> Void)?

    @State private var pendingRemoval: CodeSetManifest?

    init(model: CodeSetsViewModel, onImport: (() -> Void)? = nil) {
        self.model = model
        self.onImport = onImport
    }

    var body: some View {
        Form {
            if let failure = model.failure {
                Section {
                    Label(failure, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if model.manifests.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Code Sets Installed", systemImage: "cylinder.split.1x2")
                    } description: {
                        Text("Import ICD-10-CM, CPT, LOINC, or SNOMED CT datasets to begin clinical code searches.")
                    } actions: {
                        if let onImport {
                            Button("Import Code Set…", action: onImport)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Metric.m)
                }
            } else {
                Section {
                    ForEach(model.manifests) { manifest in
                        row(for: manifest)
                    }
                } header: {
                    HStack {
                        Text("Installed Clinical Sets")
                        Spacer()
                        if let onImport {
                            Button {
                                onImport()
                            } label: {
                                Label("Import Set…", systemImage: "plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } footer: {
                    Text("Turning a system off hides it from quick search without deleting data. Removing deletes its codes; your pinned favorites are always preserved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .id(model.preferenceRevision)

                Section {
                    HStack(spacing: Metric.m) {
                        SettingsIconBadge(systemName: "internaldrive.fill", color: .gray)

                        VStack(alignment: .leading, spacing: Metric.xxs) {
                            Text("SQLite FTS5 Search Engine")
                                .font(.body)
                            Text("\(totalCodesCount.formatted()) total clinical codes indexed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        StatusPill(text: "Optimized", systemImage: "bolt.fill", color: .green)
                    }
                    .padding(.vertical, Metric.xxs)
                } header: {
                    Text("Repository Status")
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

    private var totalCodesCount: Int {
        model.manifests.reduce(0) { $0 + $1.rowCount }
    }

    private func row(for manifest: CodeSetManifest) -> some View {
        let isEnabled = model.isSearchEnabled(manifest.system)

        return HStack(alignment: .center, spacing: Metric.m) {
            SettingsIconBadge(
                systemName: manifest.system.iconName,
                color: manifest.system.themeColor
            )

            VStack(alignment: .leading, spacing: Metric.xs) {
                HStack(spacing: Metric.s) {
                    Text(manifest.system.rawValue)
                        .font(.body)
                        .fontWeight(.semibold)

                    if let release = manifest.release {
                        StatusPill(text: "Release \(release)", color: .secondary)
                    }

                    StatusPill(text: "\(manifest.rowCount.formatted()) codes", color: .secondary)
                }

                Text(manifest.system.categorySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: .init(
                get: { model.isSearchEnabled(manifest.system) },
                set: { model.setSearchEnabled(manifest.system, $0) }
            ))
            .labelsHidden()
            .help(isEnabled ? "Disable in search" : "Enable in search")

            Menu {
                Button(role: .destructive) {
                    pendingRemoval = manifest
                } label: {
                    Label("Remove Code Set…", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
            .help("More actions for \(manifest.system.rawValue)")
        }
        .padding(.vertical, Metric.xs)
    }
}
