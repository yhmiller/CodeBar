import CodeBarUI
import CodeCore
import CodePlatform

@MainActor
final class LibraryActions {
    private let library: any CodeLibraryStoring
    private let pasteboard = SystemPasteboard()

    private(set) var pinnedIDs: Set<String> = []

    init(library: any CodeLibraryStoring) {
        self.library = library
    }

    func refresh() async {
        let pinned = (try? await library.pinnedCodes()) ?? []
        pinnedIDs = Set(pinned.map(\.id))
    }

    func isPinned(_ code: ClinicalCode) -> Bool {
        pinnedIDs.contains(code.id)
    }

    func copy(_ code: ClinicalCode, format: CopyFormat) {
        let written = format.string(for: code)
        pasteboard.write(written)
        SearchPanelController.shared.confirmation.show(written)
        Task {
            try? await library.recordUse(of: code, format: format)
            await refresh()
        }
    }

    func togglePin(_ code: ClinicalCode) {
        Task {
            try? await library.togglePin(code)
            await refresh()
        }
    }
}
