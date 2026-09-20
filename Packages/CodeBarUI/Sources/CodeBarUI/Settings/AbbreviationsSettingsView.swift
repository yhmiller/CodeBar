import CodeCore
import SwiftUI

struct AbbreviationsSettingsView: View {
    @State var model: AbbreviationsViewModel

    @State private var term = ""
    @State private var expansion = ""
    @FocusState private var isTermFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.m) {
            Text("Type a shortcut, search the words it stands for. "
                 + "CodeBar already knows \(model.builtInCount) common ones — "
                 + "add yours here, or override one it got wrong for your specialty.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            entryList

            HStack(spacing: Metric.s) {
                TextField("Shortcut", text: $term)
                    .frame(width: Metric.abbreviationTermField)
                    .focused($isTermFocused)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("Words to search for", text: $expansion)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(!model.canAdd(term: term, expansion: expansion))
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding(Metric.xl)
        .task { await model.load() }
    }

    @ViewBuilder
    private var entryList: some View {
        if model.abbreviations.isEmpty {
            VStack(spacing: Metric.xs) {
                Text("No shorthand of your own yet")
                    .foregroundStyle(.secondary)
                Text("For example, PCN → penicillin")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.abbreviations) { abbreviation in
                        row(for: abbreviation)
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: Metric.rowRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metric.rowRadius)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )
        }
    }

    private func row(for abbreviation: Abbreviation) -> some View {
        HStack(spacing: Metric.s) {
            Text(abbreviation.term)
                .font(.system(.body, design: .monospaced))
                .frame(width: Metric.abbreviationTermColumn, alignment: .leading)

            VStack(alignment: .leading, spacing: Metric.xxs) {
                Text(abbreviation.expansion)
                if let builtIn = model.overriddenBuiltIn(for: abbreviation) {
                    Text("replaces CodeBar's “\(builtIn)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                model.remove(abbreviation)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove \(abbreviation.term)")
        }
        .padding(.vertical, Metric.xxs)
    }

    private func add() {
        guard model.canAdd(term: term, expansion: expansion) else { return }
        model.add(term: term, expansion: expansion)
        term = ""
        expansion = ""
        isTermFocused = true
    }
}
