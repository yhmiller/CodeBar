import CodeCore
import SwiftUI

public struct AbbreviationsSettingsView: View {
    @State var model: AbbreviationsViewModel

    @State private var term = ""
    @State private var expansion = ""
    @State private var filterText = ""
    @State private var isBuiltInsExpanded = false
    @FocusState private var isTermFocused: Bool

    public init(model: AbbreviationsViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Form {
            Section {
                HStack(spacing: Metric.m) {
                    SettingsIconBadge(systemName: "character.book.closed.fill", color: .orange)

                    VStack(alignment: .leading, spacing: Metric.xxs) {
                        Text("Clinical Abbreviations")
                            .font(.body)
                            .fontWeight(.semibold)
                        Text("Type a shortcut to automatically search its clinical definition. CodeBar includes \(model.builtInCount) built-in terms.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Metric.xxs)
            } header: {
                Text("Overview")
            }

            Section {
                if model.abbreviations.isEmpty {
                    emptyState
                } else {
                    if model.abbreviations.count > 3 {
                        searchFilterBar
                    }

                    ForEach(filteredAbbreviations) { abbreviation in
                        abbreviationRow(for: abbreviation)
                    }

                    if !filterText.isEmpty && filteredAbbreviations.isEmpty {
                        Text("No abbreviations match “\(filterText)”")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Metric.s)
                    }
                }
            } header: {
                HStack {
                    Text("Custom Shorthand")
                    Spacer()
                    if !model.abbreviations.isEmpty {
                        StatusPill(text: "\(model.abbreviations.count) custom", color: .secondary)
                    }
                }
            }

            Section {
                HStack(spacing: Metric.s) {
                    TextField("Shortcut", text: $term)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: Metric.abbreviationTermField)
                        .focused($isTermFocused)

                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)

                    TextField("Expanded clinical phrase", text: $expansion)
                        .onSubmit(add)

                    Button(action: add) {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canAdd(term: term, expansion: expansion))
                }
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, Metric.xxs)
            } header: {
                Text("Add Abbreviation")
            }

            Section {
                DisclosureGroup(
                    isExpanded: $isBuiltInsExpanded,
                    content: {
                        builtInsGrid
                            .padding(.top, Metric.xs)
                    },
                    label: {
                        HStack {
                            Text("Built-in Clinical Dictionary")
                            Spacer()
                            StatusPill(text: "\(model.builtInCount) built-in", color: .secondary)
                        }
                    }
                )
            }
        }
        .formStyle(.grouped)
        .task { await model.load() }
    }

    // MARK: - Subviews

    private var filteredAbbreviations: [Abbreviation] {
        let trimmed = filterText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return model.abbreviations }
        let query = trimmed.lowercased()
        return model.abbreviations.filter {
            $0.term.lowercased().contains(query) || $0.expansion.lowercased().contains(query)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Metric.xs) {
            Text("No shorthand of your own yet")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("For example, PCN → penicillin")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metric.m)
    }

    private var searchFilterBar: some View {
        HStack(spacing: Metric.s) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Filter abbreviations…", text: $filterText)
                .textFieldStyle(.plain)
                .font(.caption)

            if !filterText.isEmpty {
                Button {
                    filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metric.s)
        .padding(.vertical, Metric.xs)
        .background(
            RoundedRectangle(cornerRadius: Metric.rowRadius, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Metric.rowRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func abbreviationRow(for abbreviation: Abbreviation) -> some View {
        HStack(spacing: Metric.m) {
            Text(abbreviation.term.uppercased())
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.24), lineWidth: 0.5)
                        )
                )
                .frame(minWidth: 54, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: Metric.xxs) {
                Text(abbreviation.expansion)
                    .font(.body)
                if let builtIn = model.overriddenBuiltIn(for: abbreviation) {
                    Text("replaces CodeBar's “\(builtIn)”")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Button {
                model.remove(abbreviation)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove \(abbreviation.term)")
        }
        .padding(.vertical, Metric.xxs)
    }

    private var builtInsGrid: some View {
        VStack(alignment: .leading, spacing: Metric.s) {
            Text("These standard clinical abbreviations expand automatically during search unless overridden above.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: Metric.xs) {
                ForEach(ClinicalAbbreviations.expansions.sorted(by: { $0.key < $1.key }), id: \.key) { key, val in
                    HStack(spacing: Metric.xxs) {
                        Text(key.uppercased())
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("→")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(val)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(Metric.xxs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func add() {
        guard model.canAdd(term: term, expansion: expansion) else { return }
        model.add(term: term, expansion: expansion)
        term = ""
        expansion = ""
        isTermFocused = true
    }
}
