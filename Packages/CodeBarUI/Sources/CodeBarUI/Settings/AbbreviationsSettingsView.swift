import CodeCore
import SwiftUI

/// Add and remove the shorthand a particular clinic writes.
///
/// The built-in table stops at expansions nobody argues about, which leaves out
/// most of what gets written on a real form. Everything here expands the
/// *query*, never the code: `pcn` searches as "penicillin" and the clinician
/// still chooses from what comes back.
struct AbbreviationsSettingsView: View {
    @State var model: AbbreviationsViewModel

    @State private var term = ""
    @State private var expansion = ""
    @FocusState private var isTermFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type a shortcut, search the words it stands for. "
                 + "CodeBar already knows \(model.builtInCount) common ones — "
                 + "add yours here, or override one it got wrong for your specialty.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            entryList

            HStack(spacing: 8) {
                TextField("Shortcut", text: $term)
                    .frame(width: 110)
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
        .padding(20)
        .task { await model.load() }
    }

    /// Eagerly-built rows rather than a `List`.
    ///
    /// `List` is lazy: in a hosting controller it draws its frame and no rows at
    /// all, so the first recorded snapshot of a populated pane was an empty box —
    /// a reference that would have passed forever while hiding every regression
    /// in the rows it was supposed to cover.
    @ViewBuilder
    private var entryList: some View {
        if model.abbreviations.isEmpty {
            VStack(spacing: 4) {
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
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )
        }
    }

    private func row(for abbreviation: Abbreviation) -> some View {
        HStack(spacing: 8) {
            Text(abbreviation.term)
                .font(.system(.body, design: .monospaced))
                .frame(width: 100, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(abbreviation.expansion)
                // Naming what was replaced, so an override is visible rather than
                // silent — the two readings of a letter pair usually belong to
                // different specialties.
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
        .padding(.vertical, 2)
    }

    private func add() {
        guard model.canAdd(term: term, expansion: expansion) else { return }
        model.add(term: term, expansion: expansion)
        term = ""
        expansion = ""
        isTermFocused = true
    }
}
